class Nocturne
  module Write
    class Packet
      LENGTH_PLACEHOLDER = "   ".b

      def initialize(buffer, sequence, &blk)
        @buffer = buffer
        @buffer << LENGTH_PLACEHOLDER
        @buffer << sequence
      end

      def int(bytes, value)
        bytes.times do
          @buffer << (value & 0xff)
          value >>= 8
        end
      end

      def str(value)
        @buffer << value
      end

      def nulstr(value)
        @buffer << value
        @buffer << 0
      end

      def length
        data.length
      end

      def data(offset = 0)
        write_length unless @length_written

        if offset.zero?
          @buffer
        else
          @buffer[offset..]
        end
      end

      private

      def write_length
        3.times do |i|
          byte = ((@buffer.length - 4) >> i * 8) & 0xFF
          @buffer[i] = byte.chr
        end

        @length_written
      end
    end
  end
end
