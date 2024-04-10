# frozen_string_literal: true

require "socket"
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

  def initialize(options = {})
    @options = options
    @sock = Nocturne::Socket.new(options)
    connect
  end

  def change_db(db)
    @sock.write_packet(sequence: 0) do |packet|
      packet.int(1, COM_INIT_DB)
      packet.str(db)
    end

    @sock.read_packet
  end

  alias select_db change_db

  def query(sql)
    @sock.write_packet(sequence: 0) do |packet|
      packet.int(1, COM_QUERY)
      packet.str(sql)
    end

    column_count = 0
    @sock.read_packet do |payload|
      unless payload.ok?
        column_count = payload.lenenc_int
      end
    end

    fields = []
    rows = []
    if column_count > 0
      column_count.times do
        @sock.read_packet do |column|
          column.lenenc_str
          column.lenenc_str
          column.lenenc_str
          column.lenenc_str
          column.lenenc_str
          name = column.lenenc_str
          column.lenenc_int
          column.int(2)
          column.int(4)
          type = column.int(1) # enum_field_types, I'll need a bunch of this for casting
          column.int(2)
          column.int(1)
          fields << name
        end
      end

      more_rows = true
      while more_rows
        @sock.read_packet do |row|
          if row.eof?
            more_rows = false
            break
          end

          rows << column_count.times.map do
            # TODO casting based on column details
            row.nil_or_lenenc_str
          end
        end
      end
    end

    Result.new(fields, rows)
  end

  def ping
    # TODO
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
      @auth_plugin_name = handshake.nulstr
    end

    @sock.write_packet(sequence: 1) do |packet|
      # TODO don't hardcode all this
      packet.int(4, 0x018aa200) # capabilities
      packet.int(4, 0xffffff) # max packet size
      packet.int(1, 0x2d) #charset
      packet.int(23, 0) #unused
      packet.nulstr(@options[:username] || "root")

      # TODO auth
      packet.nulstr("")
      packet.nulstr(@auth_plugin_name)
    end

    # TODO read this for real
    @sock.read_packet
  end
end
