# frozen_string_literal: true

require "socket"
require "digest"
require_relative "nocturne/error"
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
    connect
  end

  def change_db(db)
    @sock.write_packet(sequence: 0) do |packet|
      packet.int(1, COM_INIT_DB)
      packet.str(db)
    end

    @sock.read_packet
  end

  alias_method :select_db, :change_db

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
          _type = column.int(1) # enum_field_types, I'll need a bunch of this for casting
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
    @sock.write_packet(sequence: 0) do |packet|
      packet.int(1, COM_PING)
    end

    @sock.read_packet
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
      _protocol_version = handshake.int
      @server_version = handshake.nulstr
      _thread_id = handshake.int(4)
      auth_plugin_data = handshake.strn(8)
      handshake.strn(1)
      _capabilities = handshake.int(2)
      _character_set = handshake.int
      _status_flags = handshake.int(2)
      _capabilities2 = handshake.int(2)
      auth_plugin_data_len = handshake.int
      handshake.strn(10)
      @auth_plugin_data = auth_plugin_data + handshake.strn([13, auth_plugin_data_len - 8].max)
      @auth_plugin_name = handshake.nulstr
    end

    @sock.write_packet(sequence: 1) do |packet|
      # TODO don't hardcode all this
      packet.int(4, 0x018aa200) # capabilities
      packet.int(4, 0xffffff) # max packet size
      packet.int(1, 0x2d) # charset
      packet.int(23, 0) # unused
      packet.nulstr(@options[:username] || "root")

      if @auth_plugin_name == "mysql_native_password" && password?
        packet.int(1, 20)
        packet.str(mysql_native_password(@auth_plugin_data))
      else
        packet.int(1, 0)
      end

      packet.nulstr(@auth_plugin_name)
    end

    @sock.read_packet do |packet|
      if packet.ok?
        return
      elsif packet.err?
        code, message = read_error(packet)
        raise ConnectionError, "#{code}: #{message}"
      elsif packet.int == 0xFE # auth switch
        plugin = packet.nulstr
        data = packet.eof_str
        auth_switch(plugin, data)
      end
    end
  end

  def auth_switch(plugin, data)
    @sock.write_packet(sequence: 3) do |packet|
      if plugin == "mysql_native_password"
        packet.str(mysql_native_password(data)) if password?
      else
        raise "unknown auth plugin"
      end
    end

    @sock.read_packet do |packet|
      if packet.err?
        code, message = read_error(packet)
        raise ConnectionError, "#{code}: #{message}"
      end
    end
  end

  def password?
    @options[:password] && @options[:password].length > 0
  end

  def mysql_native_password(scramble)
    scramble = scramble.strip! # nul terminator
    password_digest = Digest::SHA1.digest(@options[:password] || "")
    password_double_digest = Digest::SHA1.digest(password_digest)
    scramble_digest = Digest::SHA1.digest(scramble + password_double_digest)

    bytes = password_digest.length.times.map do |i|
      password_digest.getbyte(i) ^ scramble_digest.getbyte(i)
    end

    bytes.pack("C*")
  end

  def read_error(packet)
    packet.int
    code = packet.int(2)
    packet.strn(1)
    packet.strn(5)
    message = packet.eof_str
    [code, message]
  end
end
