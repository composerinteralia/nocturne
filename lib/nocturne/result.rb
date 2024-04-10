class Nocturne
  class Result
    attr_reader :fields, :rows

    def initialize(fields, rows)
      @fields = fields
      @rows = rows
    end
  end
end
