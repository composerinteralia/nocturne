class Nocturne
  module Read
    class Payload
      def initialize(payload)
        @payload = payload
        @pos = 0
      end

      def int(bytes=1)
        result = 0

        bytes.times do |i|
          result |= @payload.getbyte(@pos) << (8 * i)
          @pos += 1
        end

        result
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
    end
  end
end
