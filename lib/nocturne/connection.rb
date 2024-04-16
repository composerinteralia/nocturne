#frozen_string_literal: true

class Nocturne
  class Connection
    def initialize(sock)
      @sock = sock
      @write_buffer = "".b
      @packet = Read::Packet.new
      @read_buffer = "".b
      @pos = 0
      @next_sequence = 0
    end

    def begin_command
      raise "unread data" unless buffer_fully_read?
      raise "unwritten data" unless @write_buffer.empty?
      @next_sequence = 0
    end

    def write_packet(&blk)
      packet = Write::Packet.new(@write_buffer, @next_sequence).tap(&blk)

      written = 0
      while written < packet.length
        written += @sock.sendmsg(packet.data(written))
      end

      @write_buffer.clear
      @next_sequence += 1
    end

    def read_packet
      @packet.reset

      loop do
        if buffer_fully_read?
          @sock.recv(@read_buffer)
          @pos = 0
        end

        @pos += @packet.parse_fragment(@read_buffer, @pos)

        if @packet.complete?
          raise "sequence out of order" if @packet.sequence != @next_sequence
          @next_sequence = @packet.sequence + 1

          # TODO: If packet continues, maybe wrap them all up into a grouped thing?
          yield @packet.payload if block_given?
          return
        end
      end
    end

    private

    def buffer_fully_read?
      @read_buffer.length == @pos
    end
  end
end
