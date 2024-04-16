#frozen_string_literal: true

class Nocturne
  module Protocol
    def self.error(packet, klass)
      code, message = read_error(packet)
      klass.new("#{code}: #{message}")
    end

    def self.read_error(packet)
      packet.int8
      code = packet.int16
      packet.strn(1)
      packet.strn(5)
      message = packet.eof_str
      [code, message]
    end
  end
end
