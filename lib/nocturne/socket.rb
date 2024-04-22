# frozen_string_literal:true

# standard:disable Lint/MissingCopEnableDirective
# standard:disable Style/YodaCondition

require "socket"
require "openssl"

class Nocturne
  class Socket
    def initialize(options)
      @sock = connect(options)
      @select_sock = [@sock]
      @options = options
    end

    MAX_BYTES = 32768

    def recv(buffer)
      loop do
        result = @sock.read_nonblock(MAX_BYTES, buffer, exception: false)

        if :wait_readable == result
          IO.select(@select_sock, nil, nil, @options[:read_timeout]) || raise(TimeoutError)
        else
          return result
        end
      end
    end

    def sendmsg(data)
      loop do
        result = @sock.write_nonblock(data, exception: false)

        if :wait_writable == result
          IO.select(nil, @select_sock, nil, @options[:write_timeout]) || raise(TimeoutError)
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

    private

    def connect(options)
      if options[:host]
        sock = ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM)
        addr = ::Socket.pack_sockaddr_in(options[:port] || 3306, options[:host] || "localhost")
        sock.connect_nonblock(addr, exception: false)
      else
        sock = ::Socket.unix(options[:socket] || "/tmp/mysql.sock")
      end

      sock
    end
  end

  class SSLSocket
    def initialize(sock, options)
      @sock = OpenSSL::SSL::SSLSocket.new(sock, ssl_context(options))
      @sock.connect
      @select_sock = [@sock]
      @options = options
    end

    def recv(buffer)
      loop do
        result = @sock.read_nonblock(Nocturne::Socket::MAX_BYTES, buffer, exception: false)

        if :wait_readable == result
          IO.select(@select_sock, nil, nil, @options[:read_timeout]) || raise(TimeoutError)
        elsif :wait_writable == result
          IO.select(nil, @select_sock, nil, @options[:write_timeout]) || raise(TimeoutError)
        else
          return result
        end
      end
    end

    def sendmsg(data)
      loop do
        result = @sock.write_nonblock(data, exception: false)

        if :wait_readable == result
          IO.select(@select_sock, nil, nil, @options[:read_timeout]) || raise(TimeoutError)
        elsif :wait_writable == result
          IO.select(nil, @select_sock, nil, @options[:write_timeout]) || raise(TimeoutError)
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
