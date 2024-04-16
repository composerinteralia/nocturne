# frozen_string_literal: true

require "socket"
require "digest"
require_relative "nocturne/connection"
require_relative "nocturne/error"
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
  SSL_PREFERRED_NOVERIFY = 4
  TLS_VERSION_12 = 3

  COM_QUIT = 1
  COM_INIT_DB = 2
  COM_QUERY = 3
  COM_PING = 14

  QUERY_FLAGS_CAST_BOOLEANS = 2

  attr_reader :server_version
  attr_accessor :query_flags

  def initialize(options = {})
    @options = options
    @sock = Nocturne::Socket.new(options)
    @conn = Nocturne::Connection.new(@sock)

    handshake = Protocol::Handshake.new(@conn, @options).tap(&:engage)
    @server_version = handshake.server_version
    @query_flags = 0
  end

  def change_db(db)
    @conn.begin_command

    @conn.write_packet do |packet|
      packet.int(1, COM_INIT_DB)
      packet.str(db)
    end

    @conn.read_packet do |payload|
      raise Protocol.error(payload, Error) if payload.err?
    end
  end

  alias_method :select_db, :change_db

  def query(sql)
    Protocol::Query.new(@conn, @options, @query_flags).query(sql)
  end

  def ping
    @conn.begin_command

    @conn.write_packet do |packet|
      packet.int(1, COM_PING)
    end

    @conn.read_packet do |payload|
      raise Protocol.error(payload, Error) if payload.err?
    end
  end

  def close
    @conn.begin_command

    @conn.write_packet do |packet|
      packet.int(1, COM_QUIT)
    end

    @sock.close
  end
end
