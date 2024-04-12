# frozen_string_literal: true

require "socket"
require "digest"
require_relative "nocturne/error"
require_relative "nocturne/protocol/connection"
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
    @sock.begin_command

    @sock.write_packet do |packet|
      packet.int(1, COM_INIT_DB)
      packet.str(db)
    end

    @sock.read_packet
  end

  alias_method :select_db, :change_db

  def query(sql)
    @sock.begin_command

    @sock.write_packet do |packet|
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

  private

  def connect
    connection = Protocol::Connection.new(@sock, @options).tap(&:establish)
    @server_version = connection.server_version
  end
end
