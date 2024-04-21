# frozen_string_literal: true

require "digest"
require_relative "nocturne/connection"
require_relative "nocturne/error"
require_relative "nocturne/escaping"
require_relative "nocturne/protocol"
require_relative "nocturne/protocol/handshake"
require_relative "nocturne/protocol/query"
require_relative "nocturne/read/packet"
require_relative "nocturne/read/payload"
require_relative "nocturne/result"
require_relative "nocturne/socket"
require_relative "nocturne/version"
require_relative "nocturne/write/packet"

class Nocturne
  include Escaping

  SSL_DISABLE = nil
  # TODO: These values are meaningless at the moment
  SSL_VERIFY_IDENTITY = 1
  SSL_VERIFY_CA = 2
  SSL_REQUIRED_NOVERIFY = 3
  SSL_PREFERRED_NOVERIFY = 4

  TLS_VERSION_10 = OpenSSL::SSL::TLS1_VERSION
  TLS_VERSION_11 = OpenSSL::SSL::TLS1_1_VERSION
  TLS_VERSION_12 = OpenSSL::SSL::TLS1_2_VERSION
  TLS_VERSION_13 = OpenSSL::SSL::TLS1_3_VERSION

  QUERY_FLAGS_NONE = 0
  QUERY_FLAGS_CAST = 1
  QUERY_FLAGS_CAST_BOOLEANS = 2
  QUERY_FLAGS_LOCAL_TIMEZONE = 4
  QUERY_FLAGS_FLATTEN_ROWS = 8
  QUERY_FLAGS_CAST_ALL_DECIMALS_TO_BIGDECIMALS = 16

  attr_reader :server_version
  attr_accessor :query_flags

  def initialize(options = {})
    @options = options
    @query_flags = QUERY_FLAGS_CAST
    connect
    change_db(options[:database]) if options[:database]
  end

  def change_db(db)
    @conn.begin_command

    @conn.write_packet do |packet|
      packet.int(1, Protocol::COM_INIT_DB)
      packet.str(db)
    end

    @conn.read_packet do |payload|
      raise Protocol.error(payload, Error) if payload.err?
    end

    true
  end

  alias_method :select_db, :change_db

  def query(sql)
    Protocol::Query.new(@conn, @options, @query_flags).query(sql)
  end

  def ping
    @conn.begin_command

    @conn.write_packet do |packet|
      packet.int(1, Protocol::COM_PING)
    end

    @conn.read_packet do |payload|
      raise Protocol.error(payload, Error) if payload.err?
    end

    true
  end

  def close
    @conn.begin_command

    @conn.write_packet do |packet|
      packet.int(1, Protocol::COM_QUIT)
    end

    @conn.close
  end

  private

  def connect
    @conn = Nocturne::Connection.new(@options)
    handshake = Protocol::Handshake.new(@conn, @options).tap(&:engage)
    @server_version = handshake.server_version
  end
end
