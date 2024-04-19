class Nocturne
  module Write
    class Packet
      LENGTH_PLACEHOLDER = "    ".b

      attr_reader :sequence

      def initialize
        @buffer = "".b
        @length = 0
      end

      def build(sequence)
        @buffer << LENGTH_PLACEHOLDER
        @sequence = sequence
        yield self
        finalize_packets
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
        if offset >= @length
          nil
        elsif offset.zero?
          @buffer
        else
          @buffer[offset..]
        end
      end

      private

      MAX_PAYLOAD_LEN = 0xFFFFFF

      def finalize_packets
        @length = @buffer.length
        remaining_length = @length - 4
        packet_start = 0

        write_packet_header(packet_start, remaining_length)

        while remaining_length >= MAX_PAYLOAD_LEN
          @sequence += 1
          remaining_length -= MAX_PAYLOAD_LEN
          packet_start += MAX_PAYLOAD_LEN + 4

          @buffer.bytesplice(packet_start, 0, LENGTH_PLACEHOLDER)
          write_packet_header(packet_start, remaining_length)
        end
      end

      def write_packet_header(packet_start, remaining_length)
        next_payload_length = [remaining_length, MAX_PAYLOAD_LEN].min
        @buffer[packet_start] = (next_payload_length & 0xff).chr
        @buffer[packet_start + 1] = ((next_payload_length >> 8) & 0xff).chr
        @buffer[packet_start + 2] = ((next_payload_length >> 16) & 0xff).chr
        @buffer[packet_start + 3] = @sequence.chr
      end
    end
  end
end
