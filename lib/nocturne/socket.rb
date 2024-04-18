# frozen_string_literal:true

class Nocturne
  class Socket
    def initialize(options)
      @sock = ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM)
      @select_sock = [@sock]
      @sock.connect ::Socket.pack_sockaddr_in(options[:port] || 3306, options[:host] || "localhost")
    end

    MAX_BYTES = 32768

    def recv(buffer)
      loop do
        result = @sock.recv_nonblock(MAX_BYTES, 0, buffer, exception: false)

        if :wait_readable == result # standard:disable Style/YodaCondition
          IO.select(@select_sock)
        else
          return result
        end
      end
    end

    def sendmsg(data)
      loop do
        result = @sock.sendmsg_nonblock(data, exception: false)

        if :wait_writable == result # standard:disable Style/YodaCondition
          IO.select(nil, @select_sock)
        else
          return result
        end
      end
    end

    def close
      @sock.close
    end
  end
end
