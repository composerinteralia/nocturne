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

        @conn.read_packet do |packet|
          if packet.ok?
            packet.skip(1)
            @conn.update_status(
              affected_rows: packet.lenenc_int,
              last_insert_id: packet.lenenc_int,
              status_flags: packet.int16,
              warnings: packet.int16
            )
          elsif packet.err?
            raise Protocol.error(packet, ConnectionError)
          elsif packet.int8 == 0xFE # auth switch
            plugin = packet.nulstr
            data = packet.eof_str
            auth_switch(plugin, data)
          else
            raise "unkwown packet"
          end
        end
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

      UNUSED = "\0".b * 23

      def ssl_request
        @conn.write_packet do |packet|
          # TODO don't hardcode all this
          packet.int32(0x018aaa00) # capabilities (ssl capability set)
          packet.int32(0xffffff) # max packet size
          packet.int8(0x2d) # charset
          packet.str(UNUSED)
        end

        @conn.upgrade
      end

      def client_handshake
        @conn.write_packet do |packet|
          # TODO don't hardcode all this
          packet.int32(0x018aa200) # capabilities (ssl capability set)
          packet.int32(0xffffff) # max packet size
          packet.int8(0x2d) # charset
          packet.str(UNUSED)

          packet.nulstr(@options[:username] || "root")

          if @auth_plugin_name == "mysql_native_password" && password?
            packet.int8(20)
            packet.str(mysql_native_password(@auth_plugin_data))
          else
            packet.int8(0)
          end

          packet.nulstr(@auth_plugin_name)
        end
      end

      def auth_switch(plugin, data)
        @conn.write_packet do |packet|
          case plugin
          when "mysql_native_password"
            packet.str(mysql_native_password(data)) if password?
          when "mysql_clear_password"
            raise AuthPluginError, "cleartext plugin not enabled" unless @options[:enable_cleartext_plugin]
            packet.str(@options[:password]) if password?
          else
            raise AuthPluginError, "unknown auth plugin"
          end
        end

        @conn.read_packet do |payload|
          raise Protocol.error(payload, ConnectionError) if payload.err?
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
    end
  end
end
