class Nocturne
  module Read
    class Payload
      def initialize(payload)
        @payload = payload
        @pos = 0
      end

      def int(bytes = 1)
        result = 0

        bytes.times do |i|
          result |= @payload.getbyte(@pos) << (8 * i)
          @pos += 1
        end

        result
      end

      def lenenc_int
        case @payload.getbyte(@pos)
        when 0xFC
          @pos += 1
          int(2)
        when 0xFD
          @pos += 1
          int(3)
        when 0xFE
          @pos += 1
          int(8)
        when 0xFF
          raise "unexpected int"
        else
          int(1)
        end
      end

      def lenenc_str
        len = lenenc_int
        @payload[@pos, len].tap { @pos += len }
      end

      def nil?
        if @payload.getbyte(@pos) == 0xFB
          @pos += 1
          true
        else
          false
        end
      end

      def nulstr
        start = @pos

        until @payload.getbyte(@pos).zero?
          @pos += 1
        end

        @payload[start...@pos].tap do
          @pos += 1
        end
      end

      def strn(n)
        @payload[@pos, n].tap do
          @pos += n
        end
      end

      def eof_str
        @payload[@pos...].tap do
          @pos = @payload.length
        end
      end

      def eof?
        @payload.getbyte(0) == 0xFE && @payload.length < 9
      end

      def ok?
        @payload.getbyte(0) == 0
      end

      def err?
        @payload.getbyte(0) == 0xFF
      end
    end
  end
end
