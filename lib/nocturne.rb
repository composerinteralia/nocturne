# frozen_string_literal: true

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
    @sock.write_packet(sequence: 0) do |packet|
      packet.int(1, COM_QUIT)
    end

    @sock.close
  end

  private

  def connect
    @sock.read_packet do |handshake|
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

    @sock.write_packet(sequence: 1) do |packet|
      # TODO don't hardcode all this
      packet.int(4, 0x018aa200) # capabilities
      packet.int(4, 0xffffff) # max packet size
      packet.int(1, 0x2d) #charset
      packet.int(23, 0) #unused
      packet.nulstr("root")

      # TODO auth
      packet.nulstr("")
      packet.nulstr("caching_sha2_password")
    end


    # TODO read this for real
    @sock.read_packet
  end
end
