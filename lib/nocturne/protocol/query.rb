#frozen_string_literal: true

require "bigdecimal"

class Nocturne
  module Protocol
    class Query
      def initialize(sock, options, flags)
        @sock = sock
        @options = options
        @flags = flags
      end

      def query(sql)
        @sock.begin_command

        @sock.write_packet do |packet|
          packet.int(1, COM_QUERY)
          packet.str(sql)
        end

        column_count = 0
        @sock.read_packet do |payload|
          if payload.ok?
            # Done. No results.
          elsif payload.err?
            raise Protocol.error(payload, QueryError)
          else
            column_count = payload.lenenc_int
          end
        end

        @columns = read_columns(column_count)
        fields = @columns.map(&:first)
        rows = read_rows(column_count)
        Result.new(fields, rows)
      end

      private

      def read_columns(column_count)
        columns = []

        column_count.times do
          @sock.read_packet do |column|
            column.skip(column.lenenc_int)
            column.skip(column.lenenc_int)
            column.skip(column.lenenc_int)
            column.skip(column.lenenc_int)
            column.skip(column.lenenc_int)
            name = column.lenenc_str
            column.lenenc_int
            charset = column.int(2)
            len = column.int(4)
            type = column.int(1)
            flags = column.int(2)
            decimals = column.int(1)

            columns << [name, charset, len, type, flags, decimals]
          end
        end

        columns
      end

      def read_rows(column_count)
        return [] if column_count.zero?

        rows = []

        more_rows = true
        while more_rows
          @sock.read_packet do |row|
            if row.eof?
              more_rows = false
              break
            end

            rows << read_row(column_count, row)
          end
        end

        rows
      end

      DECIMAL = 0
      TINY = 1
      SHORT = 2
      LONG = 3
      FLOAT = 4
      DOUBLE = 5
      # TIMESTAMP = 7
      LONGLONG = 8
      INT24 = 9
      BIT = 0x10
      # DATE = 0x0a
      # TIME = 0x0b
      # DATETIME = 0x0c
      YEAR = 0x0d
      NEWDECIMAL = 0xf6

      def read_row(column_count, row)
        column_count.times.map { |i| cast_value(row, @columns[i]) }
      end

      def cast_value(row, column)
        return if row.nil?
        # return row.lenenc_str #if casting is disabled

        name, charset, len, type, flags, decimals = column

        # TODO: maybe try to write these without all the extra strings, although
        # casting is not the slowest thing here
        case type
        when BIT
          if len == 1 && !(@flags & QUERY_FLAGS_CAST_BOOLEANS).zero?
            raise "unexpected int" if row.lenenc_int != 1
            row.int.zero? ? false : true
          else
            row.lenenc_str
          end
        when TINY
          if len == 1 && !(@flags & QUERY_FLAGS_CAST_BOOLEANS).zero?
            raise "unexpected int" if row.lenenc_int != 1
            row.strn(1) == "0" ? false : true
          else
            row.lenenc_str.to_i
          end
        when SHORT, LONG, LONGLONG, INT24, YEAR
          row.lenenc_str.to_i
        when DECIMAL, NEWDECIMAL
          if decimals.zero?
            Integer(row.lenenc_str)
          else
            BigDecimal(row.lenenc_str)
          end
        when FLOAT, DOUBLE
          Float(row.lenenc_str)
        else
          row.lenenc_str
        end
      end
    end
  end
end
