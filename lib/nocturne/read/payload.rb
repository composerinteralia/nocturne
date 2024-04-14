class Nocturne
  module Read
    class Payload
      def initialize(fragments, length)
        @fragments = fragments
        @length = length
        @pos = 0
        @fragment_pos = 0
        @fragment_i = 0
        @joined = nil
      end

      def skip(n)
        forward(n)
      end

      def int(bytes = 1)
        result = 0

        bytes.times do |i|
          result |= peek << (8 * i)
          forward(1)
        end

        result
      end

      def lenenc_int
        case peek
        when 0xFC
          forward(1)
          int(2)
        when 0xFD
          forward(1)
          int(3)
        when 0xFE
          forward(1)
          int(8)
        when 0xFF
          raise "unexpected int"
        else
          int(1)
        end
      end

      def lenenc_str
        strn(lenenc_int)
      end

      def nil?
        if peek == 0xFB
          forward(1)
          true
        else
          false
        end
      end

      def nulstr
        start = @pos

        until peek.zero?
          forward(1)
        end

        @joined ||= @fragments.join
        @joined.slice(start, @pos - start).tap do
          forward(1)
        end
      end

      def strn(n)
        result = @fragments[@fragment_i].slice(@fragment_pos, n)

        i = 1
        while result.length < n
          result << @fragments[@fragment_i + i].slice(@fragment_pos, n)
          i += 1
        end

        forward(n)
        result
      end

      def eof_str
        strn(@length - @pos)
      end

      def eof?
        byte_at(0, 0) == 0xFE && @length < 9
      end

      def ok?
        byte_at(0, 0) == 0
      end

      def err?
        byte_at(0, 0) == 0xFF
      end

      private

      def peek
        byte_at(@fragment_i, @fragment_pos)
      end

      def byte_at(i, pos)
        @fragments[i].getbyte(pos)
      end

      def forward(n)
        @pos += n
        @fragment_pos += n

        while @fragments[@fragment_i] && @fragment_pos >= @fragments[@fragment_i].length
          @fragment_pos -= @fragments[@fragment_i].length
          @fragment_i += 1
        end
      end
    end
  end
end
