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
  end
end
