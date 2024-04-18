#frozen_string_literal: true

require "bigdecimal"
require "date"

class Nocturne
  module Protocol
    class Query
      def initialize(conn, options, flags)
        @conn = conn
        @options = options
        @flags = flags
      end

      def query(sql)
        @conn.begin_command

        @conn.write_packet do |packet|
          packet.int(1, COM_QUERY)
          packet.str(sql)
        end

        column_count = 0
        @conn.read_packet do |payload|
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

        i = 0
        while i < column_count
          @conn.read_packet do |column|
            column.skip(column.lenenc_int)
            column.skip(column.lenenc_int)
            column.skip(column.lenenc_int)
            column.skip(column.lenenc_int)
            name = column.lenenc_str
            column.skip(column.lenenc_int)
            column.lenenc_int
            charset = column.int16
            len = column.int32
            type = column.int8
            flags = column.int16
            decimals = column.int8

            columns << [name, charset, len, type, flags, decimals]
          end

          i += 1
        end

        columns
      end

      def read_rows(column_count)
        return [] if column_count.zero?

        rows = []

        more_rows = true
        while more_rows
          @conn.read_packet do |row|
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
      TIMESTAMP = 7
      LONGLONG = 8
      INT24 = 9
      BIT = 0x10
      DATE = 0x0a
      TIME = 0x0b
      DATETIME = 0x0c
      YEAR = 0x0d
      NEWDECIMAL = 0xf6

      def read_row(column_count, row)
        result = []
        i = 0

        while i < column_count
          result << cast_value(row, @columns[i])
          i += 1
        end

        result
      end

      def cast_value(row, column)
        return if row.nil?
        return row.lenenc_str if (@flags & QUERY_FLAGS_CAST).zero?

        _name, _charset, len, type, _flags, decimals = column

        # TODO: maybe try to write these without all the extra strings, although
        # casting is not the slowest thing here
        case type
        when BIT
          if len == 1 && !(@flags & QUERY_FLAGS_CAST_BOOLEANS).zero?
            raise "unexpected int" if row.lenenc_int != 1
            row.int8.zero? ? false : true
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
        when TIMESTAMP, DATETIME
          if (@flags & QUERY_FLAGS_LOCAL_TIMEZONE).zero?
            Time.new(row.lenenc_str, in: "UTC")
          else
            Time.new(row.lenenc_str)
          end
        when TIME
          if (@flags & QUERY_FLAGS_LOCAL_TIMEZONE).zero?
            Time.new("2000-01-01 " + row.lenenc_str, in: "UTC")
          else
            Time.new("2000-01-01 " + row.lenenc_str)
          end
        when DATE
          Date.strptime(row.lenenc_str, "%Y-%m-%d")
        else
          row.lenenc_str
        end
      end
    end
  end
end
