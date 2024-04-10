# frozen_string_literal: true

require_relative "nocturne/version"
require_relative "nocturne/result"

class Nocturne
  SSL_PREFERRED_NOVERIFY = 4
  TLS_VERSION_12 = 3

  def initialize(*)
  end

  def change_db(*)
  end

  def query(*)
    Result.new
  end

  def ping
    true
  end

  def close
  end
end
