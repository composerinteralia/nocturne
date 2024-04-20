# frozen_string_literal:true

class Nocturne
  class Connection
    def initialize(options)
      @sock = Nocturne::Socket.new(options)
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

      written = 0
      while (data = @write.data(written))
        written += @sock.sendmsg(data)
      end

      @next_sequence = @write.sequence + 1
    ensure
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

    def upgrade
      @sock = @sock.ssl_sock
    end

    def close
      @sock.close
    end

    private

    def buffer_fully_read?
      @read_len == @read_pos
    end
  end
end
