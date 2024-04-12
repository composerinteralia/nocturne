# frozen_string_literal: true

class Nocturne
  class Error < StandardError
  end

  class ConnectionError < Error
  end

  class QueryError < Error
  end
end
