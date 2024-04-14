class Nocturne
  module Read
    class Packet
      attr_reader :sequence

      def initialize
        @state = 0
        @payload_bytes_read = 0
        @fragments = []
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
      def parse_fragment(fragment, offset)
        i = offset

        while i < fragment.length
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
            payload_fragment = fragment[i, @payload_len - @payload_bytes_read]
            @fragments << payload_fragment
            @payload_bytes_read += payload_fragment.length
            i += payload_fragment.length
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

      MAX_PAYLOAD_LEN = 0xFFFFFF

      def continues?
        @payload_len == MAX_PAYLOAD_LEN
      end

      def payload
        # TODO: do we actually need to join the fragments together at all?
        # Maybe rewrite the payload class to be able to read directly from the
        # fragments instead. Or maybe read the fragments lazily as needed (that
        # might make it easier to do the continuation stuff too).
        Read::Payload.new(@fragments, @payload_len)
      end
    end
  end
end
