class Nocturne
  class Result
    include Enumerable

    attr_reader :fields, :rows, :affected_rows, :last_insert_id

    def initialize(fields, rows, conn)
      @fields = fields
      @rows = rows
      @affected_rows = conn.affected_rows
      @last_insert_id = conn.last_insert_id
    end

    def each(&bk)
      rows.each(&bk)
    end

    def each_hash
      return enum_for(:each_hash) unless block_given?

      rows.each do |row|
        this_row = {}

        idx = 0
        row.each do |col|
          this_row[fields[idx]] = col
          idx += 1
        end

        yield this_row
      end

      self
    end
  end
end
