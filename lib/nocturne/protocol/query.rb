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
        fields = @columns.map(&:name)
        rows = read_rows(column_count)
        Result.new(fields, rows)
      end

      private

      Column = Data.define(:name, :charset, :len, :type, :flags, :decimals)

      def read_columns(column_count)
        columns = []

        column_count.times do
          @sock.read_packet do |column|
            column.lenenc_str
            column.lenenc_str
            column.lenenc_str
            column.lenenc_str
            column.lenenc_str
            name = column.lenenc_str.get_string
            column.lenenc_int
            charset = column.int(2)
            len = column.int(4)
            type = column.int(1)
            flags = column.int(2)
            decimals = column.int(1)

            columns << Column.new(name, charset, len, type, flags, decimals)
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

        # TODO: try to write these without all the extra strings
        case column.type
        when BIT
          if column.len == 1 && !(@flags & QUERY_FLAGS_CAST_BOOLEANS).zero?
            raise "unexpected int" if row.lenenc_int != 1
            row.int.zero? ? false : true
          else
            row.lenenc_str.get_string
          end
        when TINY
          if column.len == 1 && !(@flags & QUERY_FLAGS_CAST_BOOLEANS).zero?
            raise "unexpected int" if row.lenenc_int != 1
            row.int == "0".ord ? false : true
          else
            row.lenenc_int.times.inject(0) do |n|
              n *= 10
              n += (row.int - "0".ord)
            end
          end
        when SHORT, LONG, LONGLONG, INT24, YEAR
          # TODO Definitely broken for negative
          row.lenenc_int.times.inject(0) do |n|
            n *= 10
            n += (row.int - "0".ord)
          end
        when DECIMAL, NEWDECIMAL
          # TODO Definitely broken for negative
          if column.decimals.zero?
            row.lenenc_int.times.inject(0) do |n|
              n *= 10
              n += (row.int - "0".ord)
            end
          else
            decimal_place = false
            row.lenenc_int.times.inject(BigDecimal(0)) do |n|
              byte = row.int
              if decimal_place
                n += (byte - "0".ord).fdiv(decimal_place)
                decimal_place *= 10
              elsif byte == ".".ord
                decimal_place = 10
              else
                n *= 10
                n += (byte - "0".ord)
              end
              n
            end
          end
        when FLOAT, DOUBLE
          decimal_place = false
          row.lenenc_int.times.inject(0.to_f) do |n|
            byte = row.int
            if decimal_place
              n += (byte - "0".ord).fdiv(decimal_place)
              decimal_place *= 10
            elsif byte == ".".ord
              decimal_place = 10
            else
              n *= 10
              n += (byte - "0".ord)
            end
            n
          end
        else
          row.lenenc_str.get_string
        end
      end
    end
  end
end
