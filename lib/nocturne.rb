# frozen_string_literal: true

require_relative "nocturne/packet"
require_relative "nocturne/payload"
require_relative "nocturne/result"
require_relative "nocturne/socket"
require_relative "nocturne/version"

class Nocturne
  SSL_PREFERRED_NOVERIFY = 4
  TLS_VERSION_12 = 3

  def initialize(*)
    @sock = Nocturne::Socket.new
    connect
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

  private

  def connect
    handshake_packet = @sock.read_packet
    handshake_packet.payload do |handshake|
      protocol_version = handshake.int
      server_version = handshake.nulstr
      thread_id = handshake.int(4)
      auth_plugin_data1 = handshake.strn(8)
      handshake.strn(1)
      capabilities = handshake.int(2)
      character_set = handshake.int
      status_flags = handshake.int(2)
      capabilities2 = handshake.int(2)
      auth_plugin_data_len = handshake.int
      handshake.strn(10)
      auth_plutin_data2 = handshake.strn([13, auth_plugin_data_len - 8].max)
      auth_plugin_name = handshake.nulstr
    end
  end
end
