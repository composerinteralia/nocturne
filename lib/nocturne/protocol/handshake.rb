# frozen_string_literal: true

class Nocturne
  module Protocol
    class Handshake
      attr_reader :server_version

      def initialize(conn, options)
        @conn = conn
        @options = options
      end

      def engage
        server_handshake
        ssl_request if @options[:ssl_mode]
        client_handshake
        auth_response
      end

      private

      def server_handshake
        original_read_timeout = @options[:read_timeout]
        @options[:read_timeout] = @options[:connect_timeout] || @options[:write_timeout]

        @conn.read_packet do |handshake|
          raise Protocol.error(handshake, ConnectionError) if handshake.err?

          _protocol_version = handshake.int8
          @server_version = handshake.nulstr
          _thread_id = handshake.int32
          auth_plugin_data = handshake.strn(8)
          handshake.skip(1)
          _capabilities = handshake.int16
          _character_set = handshake.int8
          @conn.update_status(status_flags: handshake.int16)
          _capabilities2 = handshake.int16
          auth_plugin_data_len = handshake.int8
          handshake.skip(10)
          @auth_plugin_data = auth_plugin_data + handshake.strn([13, auth_plugin_data_len - 8].max)
          @auth_plugin_name = handshake.nulstr
        end
      ensure
        @options[:read_timeout] = original_read_timeout
      end

      CAPABILITIES = {
        found_rows: 2,
        connect_with_db: 8,
        protocol_41: 0x200,
        ssl: 0x800,
        transactions: 0x2000,
        secure_connection: 0x8000,
        multi_statements: 0x10000,
        multi_results: 0x20000,
        plugin_auth: 0x80000,
        session_track: 0x800000,
        deprecate_eof: 0x1000000
      }
      DEFAULT_CAPABILITES = CAPABILITIES[:protocol_41] |
        CAPABILITIES[:transactions] |
        CAPABILITIES[:secure_connection] |
        CAPABILITIES[:multi_results] |
        CAPABILITIES[:plugin_auth] |
        CAPABILITIES[:session_track] |
        CAPABILITIES[:deprecate_eof]

      def capabilities(ssl: false)
        cap = DEFAULT_CAPABILITES
        cap |= CAPABILITIES[:found_rows] if @options[:found_rows]
        cap |= CAPABILITIES[:connect_with_db] if @options[:database]
        cap |= CAPABILITIES[:multi_statements] if @options[:multi_statement]
        cap &= ~CAPABILITIES[:multi_results] if @options[:multi_result] == false
        cap |= CAPABILITIES[:ssl] if ssl
        cap
      end

      UNUSED = "\0".b * 23

      def ssl_request
        @conn.write_packet do |packet|
          packet.int32(capabilities(ssl: true))
          packet.int32(Protocol::MAX_PAYLOAD_LEN)
          packet.int8(Nocturne::Encoding.charset(@options[:encoding]))
          packet.str(UNUSED)
        end

        @conn.upgrade
      end

      def client_handshake
        @conn.write_packet do |packet|
          packet.int32(capabilities)
          packet.int32(Protocol::MAX_PAYLOAD_LEN)
          packet.int8(Nocturne::Encoding.charset(@options[:encoding]))
          packet.str(UNUSED)

          packet.nulstr(@options[:username] || "root")

          authdata = if @auth_plugin_name == "mysql_native_password" && password?
            mysql_native_password(@auth_plugin_data)
          elsif @auth_plugin_name == "caching_sha2_password" && password?
            caching_sha2_password(@auth_plugin_data)
          else
            ""
          end

          packet.int8(authdata.length)
          packet.str(authdata)

          packet.nulstr(@options[:database]) if @options[:database]
          packet.nulstr(@auth_plugin_name)
        end
      end

      AUTH_SWITCH = 0xFE
      AUTH_MORE_DATA = 1

      def auth_response
        @conn.read_packet do |packet|
          if packet.ok?
            next
          elsif packet.err?
            raise Protocol.error(packet, ConnectionError)
          elsif packet.tag == AUTH_SWITCH
            packet.skip(1)
            plugin = packet.nulstr
            data = packet.eof_str
            auth_switch(plugin, data)
          elsif packet.tag == AUTH_MORE_DATA
            packet.skip(1)
            auth_more_data(packet)
          else
            raise "unkwown packet"
          end
        end
      end

      def auth_switch(plugin, data)
        @conn.write_packet do |packet|
          case plugin
          when "mysql_native_password"
            packet.str(mysql_native_password(data)) if password?
          when "caching_sha2_password"
            packet.str(caching_sha2_password(data)) if password?
          when "mysql_clear_password"
            raise AuthPluginError, "cleartext plugin not enabled" unless @options[:enable_cleartext_plugin]
            packet.str(@options[:password]) if password?
          else
            raise AuthPluginError, "unknown auth plugin"
          end
        end

        auth_response
      end

      FAST_OK = 3
      FAST_FAIL = 4

      def auth_more_data(packet)
        if !@options[:ssl] && !@options[:socket]
          raise ConnectionError, "caching_sha2_password requires either TCP with TLS or a unix socket"
        end

        case packet.int8
        when FAST_FAIL
          @conn.write_packet do |packet|
            packet.nulstr(@options[:password])
          end
        when FAST_OK
          # Nothing to do
        else
          raise "unexpected packet"
        end

        @conn.read_packet do |packet|
          raise Protocol.error(packet, ConnectionError) if packet.err?
        end
      end

      def password?
        @options[:password] && @options[:password].length > 0
      end

      def mysql_native_password(scramble)
        scramble = scramble.strip! # nul terminator
        password_digest = Digest::SHA1.digest(@options[:password] || "")
        password_double_digest = Digest::SHA1.digest(password_digest)
        scramble_digest = Digest::SHA1.digest(scramble + password_double_digest)

        bytes = password_digest.length.times.map do |i|
          password_digest.getbyte(i) ^ scramble_digest.getbyte(i)
        end

        bytes.pack("C*")
      end

      def caching_sha2_password(nonce)
        nonce = nonce.strip!
        password_digest = Digest::SHA256.digest(@options[:password] || "")
        password_double_digest = Digest::SHA256.digest(password_digest)
        scramble_digest = Digest::SHA256.digest(password_double_digest + nonce)

        bytes = password_digest.length.times.map do |i|
          password_digest.getbyte(i) ^ scramble_digest.getbyte(i)
        end

        bytes.pack("C*")
      end
    end
  end
end
