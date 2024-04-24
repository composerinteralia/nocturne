# frozen_string_literal: true

class Nocturne
  module Protocol
    COM_QUIT = 1
    COM_INIT_DB = 2
    COM_QUERY = 3
    COM_PING = 14

    SERVER_STATUS_IN_TRANS = 1
    SERVER_STATUS_AUTOCOMMIT = 2
    SERVER_STATUS_MORE_RESULTS_EXIST = 8
    SERVER_STATUS_NO_GOOD_INDEX_USED = 0x10
    SERVER_STATUS_CURSOR_EXISTS = 0x40
    SERVER_STATUS_LAST_ROW_SENT = 0x80
    SERVER_STATUS_DB_DROPPED = 0x100
    SERVER_STATUS_NO_BACKSLASH_ESCAPES = 0x200
    SERVER_STATUS_METADATA_CHANGED = 0x400
    SERVER_STATUS_QUERY_WAS_SLOW = 0x800
    SERVER_STATUS_PS_OUT_PARAMS = 0x1000
    SERVER_STATUS_IN_TRANS_READONLY = 0x2000
    SERVER_STATUS_SESSION_STATE_CHANGED = 0x4000

    MAX_PAYLOAD_LEN = 0xFFFFFF

    def self.error(packet, klass)
      code, message = read_error(packet)
      klass.new("#{code}: #{message}", code)
    end

    def self.read_error(packet)
      packet.skip(1) # Error
      code = packet.int16
      packet.skip(6) # SQL state
      message = packet.eof_str
      [code, message]
    end
  end
end
