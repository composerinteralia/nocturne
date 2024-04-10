class Nocturne
  class Socket
    def initialize
      @sock = ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM)
      @sock.connect ::Socket.pack_sockaddr_in(3306, "127.0.0.1")
      @read_buffer = "".b
      @pos = 0
    end

    def read_packet
      packet = Packet.new

      loop do
        recv if @read_buffer.length == @pos

        @pos += packet.parse_fragment(@read_buffer, @pos)
        return packet if packet.complete?
      end
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
  end
end
