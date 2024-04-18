# frozen_string_literal:true

class Nocturne
  class Connection
    def initialize(sock)
      @sock = sock
      @write = Write::Packet.new
      @read = Read::Packet.new
      @read_buffer = "".b
      @read_pos = 0
      @read_len = 0
      @next_sequence = 0
    end

    def begin_command
      raise "unread data" unless buffer_fully_read?
      raise "unwritten data" unless @write.empty?
      @next_sequence = 0
    end

    def write_packet(&blk)
      @write.build(@next_sequence, &blk)

      # TODO: writing packets longer than 0xFFFFFF
      written = 0
      write_len = @write.length
      while written < write_len
        written += @sock.sendmsg(@write.data(written))
      end

      @next_sequence += 1
      @write.reset
    end

    def read_packet
      @read.reset

      loop do
        @read.new_packet

        until @read.complete?
          if buffer_fully_read?
            @sock.recv(@read_buffer)
            @read_len = @read_buffer.length
            @read_pos = 0
          end

          @read_pos += @read.parse_fragment(@read_buffer, @read_len, @read_pos)
        end

        raise "sequence out of order" if @read.sequence != @next_sequence
        @next_sequence = @read.sequence + 1

        break unless @read.continues?
      end

      yield @read.payload if block_given?
    end

    private

    def buffer_fully_read?
      @read_len == @read_pos
    end
  end
end
