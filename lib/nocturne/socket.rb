class Nocturne
  class Socket
    def initialize(options)
      @sock = ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM)
      @sock.connect ::Socket.pack_sockaddr_in(options[:port] || 3306, options[:host] || "localhost")
      @write_buffer = "".b
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
        written += sendmsg(packet.data(written))
      end

      @write_buffer.clear
      @next_sequence += 1
    end

    def read_packet
      packet = Read::Packet.new

      loop do
        recv if buffer_fully_read?

        @pos += packet.parse_fragment(@read_buffer, @pos)

        if packet.complete?
          raise "sequence out of order" if packet.sequence != @next_sequence
          @next_sequence = packet.sequence + 1

          # TODO: If packet continues, maybe wrap them all up into a grouped thing?
          yield packet.payload if block_given?
          return
        end
      end
    end

    def close
      @sock.close
    end

    private

    MAX_BYTES = 32768

    def recv
      @sock.recv_nonblock(MAX_BYTES, 0, @read_buffer)
      @pos = 0
    rescue IO::WaitReadable
      IO.select([@sock])
      retry
    end

    def sendmsg(data)
      @sock.sendmsg_nonblock(data)
    rescue IO::WaitWritable
      IO.select(nil, [@sock])
      retry
    end

    def buffer_fully_read?
      @read_buffer.length == @pos
    end
  end
end
