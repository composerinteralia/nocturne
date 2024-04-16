class Nocturne
  module Read
    class Payload
      def initialize(payload)
        @payload = payload
        @pos = 0
      end

      def skip(n)
        @pos += n
      end

      def int8
        result = @payload.getbyte(@pos)
        @pos += 1
        result
      end

      def int16
        i = @pos
        @pos += 2

        @payload.getbyte(i) << 8 |
          @payload.getbyte(i + 1)
      end

      def int24
        i = @pos
        @pos += 3

        @payload.getbyte(i) << 16 |
          @payload.getbyte(i + 1) << 8 |
          @payload.getbyte(i + 2)
      end

      def int32
        i = @pos
        @pos += 4

        @payload.getbyte(i) << 24 |
          @payload.getbyte(i + 1) << 16 |
          @payload.getbyte(i + 2) << 8 |
          @payload.getbyte(i + 3)
      end

      def int64
        i = @pos
        @pos += 8

        @payload.getbyte(i) << 56 |
          @payload.getbyte(i + 1) << 48 |
          @payload.getbyte(i + 2) << 40 |
          @payload.getbyte(i + 3) << 32 |
          @payload.getbyte(i + 4) << 24 |
          @payload.getbyte(i + 5) << 16 |
          @payload.getbyte(i + 6) << 8 |
          @payload.getbyte(i + 7)
      end

      def lenenc_int
        case @payload.getbyte(@pos)
        when 0xFC
          @pos += 1
          int16
        when 0xFD
          @pos += 1
          int24
        when 0xFE
          @pos += 1
          int64
        when 0xFF
          raise "unexpected int"
        else
          int8
        end
      end

      def lenenc_str
        strn(lenenc_int)
      end

      def strn(n)
        result = @payload[@pos, n]
        @pos += n
        result
      end

      def eof_str
        strn(@payload.length - @pos)
      end

      def nulstr
        start = @pos

        until @payload.getbyte(@pos).zero?
          @pos += 1
        end

        result = @payload[start...@pos]
        @pos += 1
        result
      end

      def nil?
        if @payload.getbyte(@pos) == 0xFB
          @pos += 1
          true
        else
          false
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
