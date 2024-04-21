class Nocturne
  module Read
    class Payload
      def initialize
        @pos = 0
      end

      def fragments=(fragments)
        @payload = (fragments.length == 1) ? fragments.first : fragments.join
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

        @payload.getbyte(i) | @payload.getbyte(i + 1) << 8
      end

      def int24
        i = @pos
        @pos += 3

        @payload.getbyte(i) |
          @payload.getbyte(i + 1) << 8 |
          @payload.getbyte(i + 2) << 16
      end

      def int32
        i = @pos
        @pos += 4

        @payload.getbyte(i) |
          @payload.getbyte(i + 1) << 8 |
          @payload.getbyte(i + 2) << 16 |
          @payload.getbyte(i + 3) << 24
      end

      def int64
        i = @pos
        @pos += 8

        @payload.getbyte(i) |
          @payload.getbyte(i + 1) << 8 |
          @payload.getbyte(i + 2) << 16 |
          @payload.getbyte(i + 3) << 24 |
          @payload.getbyte(i + 4) << 32 |
          @payload.getbyte(i + 5) << 40 |
          @payload.getbyte(i + 6) << 48 |
          @payload.getbyte(i + 7) << 56
      end

      def lenenc_int
        byte = @payload.getbyte(@pos)
        @pos += 1

        if byte < 0xFC
          byte
        elsif byte == 0xFC
          int16
        elsif byte == 0xFD
          int24
        elsif byte == 0xFE
          int64
        else
          raise "unexpected int"
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
