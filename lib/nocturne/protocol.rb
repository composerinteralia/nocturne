# frozen_string_literal: true

class Nocturne
  module Protocol
    COM_QUIT = 1
    COM_INIT_DB = 2
    COM_QUERY = 3
    COM_PING = 14

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
