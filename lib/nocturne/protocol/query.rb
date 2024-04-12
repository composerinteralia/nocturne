#frozen_string_literal: true

class Nocturne
  module Protocol
    class Query
      def initialize(sock, options)
        @sock = sock
        @options = options
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

        fields = read_fields(column_count)
        rows = read_rows(column_count)
        Result.new(fields, rows)
      end

      private

      def read_fields(column_count)
        fields = []

        column_count.times do
          @sock.read_packet do |column|
            column.lenenc_str
            column.lenenc_str
            column.lenenc_str
            column.lenenc_str
            column.lenenc_str
            name = column.lenenc_str
            column.lenenc_int
            column.int(2)
            column.int(4)
            _type = column.int(1) # enum_field_types, I'll need a bunch of this for casting
            column.int(2)
            column.int(1)
            fields << name
          end
        end

        fields
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

      def read_row(column_count, row)
        column_count.times.map do
          # TODO casting based on column details
          row.nil_or_lenenc_str
        end
      end
    end
  end
end
