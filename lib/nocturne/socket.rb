# frozen_string_literal:true

require "socket"
require "openssl"

class Nocturne
  class Socket
    def initialize(options)
      @options = options
      @sock = ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM)
      @select_sock = [@sock]
      @sock.connect ::Socket.pack_sockaddr_in(options[:port] || 3306, options[:host] || "localhost")
    end

    MAX_BYTES = 32768

    def recv(buffer)
      loop do
        result = @sock.read_nonblock(MAX_BYTES, buffer, exception: false)

        if :wait_readable == result # standard:disable Style/YodaCondition
          IO.select(@select_sock)
        else
          return result
        end
      end
    end

    def sendmsg(data)
      loop do
        result = @sock.write_nonblock(data, exception: false)

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

    def ssl_sock
      Nocturne::SSLSocket.new(@sock, @options)
    end
  end

  class SSLSocket
    def initialize(sock, options)
      @sock = OpenSSL::SSL::SSLSocket.new(sock, ssl_context(options))
      @sock.connect
      @select_sock = [@sock]
    end

    MAX_BYTES = 32768

    def recv(buffer)
      loop do
        result = @sock.read_nonblock(MAX_BYTES, buffer, exception: false)

        if :wait_readable == result # standard:disable Style/YodaCondition
          IO.select(@select_sock)
        elsif :wait_writable == result # standard:disable Style/YodaCondition
          IO.select(nil, @select_sock)
        else
          return result
        end
      end
    end

    def sendmsg(data)
      loop do
        result = @sock.write_nonblock(data, exception: false)

        if :wait_readable == result # standard:disable Style/YodaCondition
          IO.select(@select_sock)
        elsif :wait_writable == result # standard:disable Style/YodaCondition
          IO.select(nil, @select_sock)
        else
          return result
        end
      end
    end

    def close
      @sock.close
    end

    private

    def ssl_context(options)
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.min_version = options[:tls_min_version] if options[:tls_min_version]
      ctx.max_version = options[:tls_max_version]
      ctx.ciphersuites = options[:tls_ciphersuites]
      ctx.ciphers = options[:ssl_cipher]
      ctx
    end
  end
end
