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
          result |= getbyte(@pos) << (8 * i)
          @pos += 1
        end

        result
      end

      def lenenc_int
        case getbyte(@pos)
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
        @payload.slice(@pos, len).tap { @pos += len }
      end

      def nil?
        if getbyte(@pos) == 0xFB
          @pos += 1
          true
        else
          false
        end
      end

      def nulstr
        start = @pos

        until getbyte(@pos).zero?
          @pos += 1
        end

        @payload.slice(start, @pos - start).tap do
          @pos += 1
        end
      end

      def strn(n)
        @payload.slice(@pos, n).tap do
          @pos += n
        end
      end

      def eof_str
        @payload.slice(@pos).tap do
          @pos = @payload.size
        end
      end

      def eof?
        getbyte(0) == 0xFE && @payload.size < 9
      end

      def ok?
        getbyte(0) == 0
      end

      def err?
        getbyte(0) == 0xFF
      end

      private

      def getbyte(offset)
        @payload.get_value(:U8, offset)
      end
    end
  end
end
