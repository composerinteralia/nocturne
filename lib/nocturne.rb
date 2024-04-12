# frozen_string_literal: true

require "socket"
require "digest"
require_relative "nocturne/error"
require_relative "nocturne/protocol/connection"
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

  attr_reader :server_version

  def initialize(options = {})
    @options = options
    @sock = Nocturne::Socket.new(options)

    connection = Protocol::Connection.new(@sock, @options).tap(&:establish)
    @server_version = connection.server_version
  end

  def change_db(db)
    @sock.begin_command

    @sock.write_packet do |packet|
      packet.int(1, COM_INIT_DB)
      packet.str(db)
    end

    @sock.read_packet
  end

  alias_method :select_db, :change_db

  def query(sql)
    Protocol::Query.new(@sock, @options).query(sql)
  end

  def ping
    @sock.begin_command

    @sock.write_packet do |packet|
      packet.int(1, COM_PING)
    end

    @sock.read_packet
  end

  def close
    @sock.begin_command

    @sock.write_packet do |packet|
      packet.int(1, COM_QUIT)
    end

    @sock.close
  end
end
