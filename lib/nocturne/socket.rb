#frozen_string_literal:true

class Nocturne
  class Socket
    def initialize(options)
      @sock = ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM)
      @sock.connect ::Socket.pack_sockaddr_in(options[:port] || 3306, options[:host] || "localhost")
    end

    MAX_BYTES = 32768

    def recv(buffer)
      @sock.recv_nonblock(MAX_BYTES, 0, buffer)
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

    def close
      @sock.close
    end
  end
end
