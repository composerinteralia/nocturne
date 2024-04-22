# frozen_string_literal: true

class Nocturne
  class Error < StandardError
    attr_reader :error_code

    def initialize(message = nil, error_code = nil)
      @error_code = error_code
      super(message)
    end
  end

  class AuthPluginError < Error
  end

  class ConnectionError < Error
  end

  class ConnectionClosed < ConnectionError
  end

  class QueryError < Error
  end

  class TimeoutError < Error
  end
end
