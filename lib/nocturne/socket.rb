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

    def upgrade
      Nocturne::SSLSocket.new(@sock, @options)
    end

    private

    def connect(options)
      if options[:host]
        sock = ::Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM)
        addr = ::Socket.pack_sockaddr_in(options[:port] || 3306, options[:host])
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
      @sock.hostname = options[:host]
      @sock.connect
      @select_sock = [@sock]
      @options = options
    rescue OpenSSL::SSL::SSLError => e
      raise Nocturne::SSLError, e.message
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
    rescue OpenSSL::SSL::SSLError => e
      raise Nocturne::SSLError, e.message
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
    rescue OpenSSL::SSL::SSLError => e
      raise Nocturne::SSLError, e.message
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
      ctx.ca_file = options[:ssl_ca]
      ctx.ca_path = options[:ssl_capath]

      if options[:ssl_cert] && options[:ssl_key]
        begin
          cert = OpenSSL::X509::Certificate.new(File.read(options[:ssl_cert]))
          key = OpenSSL::PKey::RSA.new(File.read(options[:ssl_key]))
          ctx.add_certificate(cert, key)
        rescue ArgumentError => e
          raise Nocturne::SSLError, e.message
        end
      elsif options[:ssl_cert]
        raise Nocturne::SSLError, "no private key assigned"
      elsif options[:ssl_key]
        raise Nocturne::SSLError, "no certificate assigned"
      end

      if options[:ssl_crl] || options[:ssl_crlpath]
        store = OpenSSL::X509::Store.new
        store.add_file(options[:ssl_crl]) if options[:ssl_crl]
        store.add_path(options[:ssl_crlpath]) if options[:ssl_crlpath]
        ctx.cert_store = store
      end

      case options[:ssl_mode]
      when SSL_VERIFY_IDENTITY
        ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ctx.verify_hostname = true
      when SSL_VERIFY_CA
        ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ctx.verify_hostname = false
      when SSL_REQUIRED_NOVERIFY, SSL_PREFERRED_NOVERIFY
        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
        ctx.verify_hostname = false
      end

      ctx
    end
  end
end
