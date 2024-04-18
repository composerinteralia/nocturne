class Nocturne
  class Result
    include Enumerable

    attr_reader :fields, :rows

    def initialize(fields, rows)
      @fields = fields
      @rows = rows
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
