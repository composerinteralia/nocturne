class Nocturne
  module Write
    class Packet
      LENGTH_PLACEHOLDER = "   ".b

      attr_reader :length

      def initialize
        @buffer = "".b
        @length = 0
      end

      def build(sequence)
        @buffer << LENGTH_PLACEHOLDER
        @buffer << sequence
        yield self
        write_length
      end

      def reset
        @buffer.clear
        @length = 0
      end

      def empty?
        @buffer.empty?
      end

      def int(bytes, value)
        while bytes > 0
          @buffer << (value & 0xff)
          value >>= 8
          bytes -= 1
        end
      end

      def str(value)
        @buffer << value
      end

      def nulstr(value)
        @buffer << value
        @buffer << 0
      end

      def data(offset = 0)
        if offset.zero?
          @buffer
        else
          @buffer[offset..]
        end
      end

      private

      def write_length
        payload_length = @length = @buffer.length
        payload_length -= 4

        @buffer[0] = (payload_length & 0xff).chr
        @buffer[1] = ((payload_length >> 8) & 0xff).chr
        @buffer[2] = ((payload_length >> 16) & 0xff).chr
      end
    end
  end
end
