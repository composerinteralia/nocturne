class Nocturne
  module Read
    class Packet
      attr_reader :sequence

      def initialize
        @payload = Read::Payload.new
        @fragments = []
        reset
      end

      def reset
        @fragments.clear
      end

      def new_packet
        @state = 0
        @payload_bytes_read = 0
        @payload_len = nil
        @sequence = nil
      end

      # Packet stucture is:
      #   - 3 byte payload length
      #   - 1 byte sequence number
      #   - payload
      # We won't necessarily read all the bytes for a packet at once, so we need
      # to be able to call this method with the next fragment(s) and pick up where
      # we left off.
      def parse_fragment(fragment, length, offset)
        i = offset
        initial_state = @state

        while i < length
          case @state
          when 0
            @payload_len = fragment.getbyte(i)
          when 1
            @payload_len |= fragment.getbyte(i) << 8
          when 2
            @payload_len |= fragment.getbyte(i) << 16
          when 3
            @sequence = fragment.getbyte(i)
          else
            payload_fragment_length = [@payload_len - @payload_bytes_read, length - offset - (4 - initial_state)].min
            @fragments << fragment[i, payload_fragment_length]
            @payload_bytes_read += payload_fragment_length
            i += payload_fragment_length
            break
          end

          @state += 1
          i += 1
        end

        i - offset
      end

      def complete?
        @payload_len == @payload_bytes_read
      end

      def continues?
        @payload_len == Protocol::MAX_PAYLOAD_LEN
      end

      def payload
        @payload.fragments = @fragments
        @payload
      end
    end
  end
end
