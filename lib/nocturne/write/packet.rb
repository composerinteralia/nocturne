class Nocturne
  module Write
    class Packet
      HEADER_PLACEHOLDER = "    ".b
      HEADER_LENGTH = HEADER_PLACEHOLDER.length

      attr_reader :sequence

      def initialize
        @buffer = "".b
        @length = 0
      end

      def build(sequence, options)
        @buffer << HEADER_PLACEHOLDER
        @sequence = sequence
        yield self
        check_max_allowed_packet(options[:max_allowed_packet]) if options[:max_allowed_packet]
        finalize_packets
      end

      def reset
        @buffer.clear
        @length = 0
      end

      def empty?
        @buffer.empty?
      end

      def int8(value)
        @buffer << (value & 0xFF)
      end

      def int32(value)
        @buffer << (value & 0xFF)
        @buffer << ((value >> 8) & 0xFF)
        @buffer << ((value >> 16) & 0xFF)
        @buffer << ((value >> 24) & 0xFF)
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

      def check_max_allowed_packet(max_allowed_packet)
        if @buffer.length - HEADER_LENGTH >= max_allowed_packet
          raise QueryError, "max packet exceeded"
        end
      end

      MAX_PAYLOAD_LEN = 0xFFFFFF

      def finalize_packets
        @length = @buffer.length
        remaining_length = @length - HEADER_LENGTH
        packet_start = 0

        write_packet_header(packet_start, remaining_length)

        while remaining_length >= MAX_PAYLOAD_LEN
          @sequence += 1
          remaining_length -= MAX_PAYLOAD_LEN
          packet_start += MAX_PAYLOAD_LEN + 4

          @buffer.bytesplice(packet_start, 0, HEADER_PLACEHOLDER)
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
