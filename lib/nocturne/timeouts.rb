# frozen_string_literal: true

class Nocturne
  module Timeouts
    def read_timeout=(timeout)
      raise ConnectionClosed if @conn.closed?
      @options[:read_timeout] = timeout
    end

    def read_timeout
      raise ConnectionClosed if @conn.closed?
      @options[:read_timeout]
    end

    def write_timeout=(timeout)
      raise ConnectionClosed if @conn.closed?
      @options[:write_timeout] = timeout
    end

    def write_timeout
      raise ConnectionClosed if @conn.closed?
      @options[:write_timeout]
    end
  end
end
