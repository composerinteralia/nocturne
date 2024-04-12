# frozen_string_literal: true

class Nocturne
  module Protocol
    class Connection
      attr_reader :server_version

      def initialize(sock, options)
        @sock = sock
        @options = options
      end

      def establish
        server_handshake
        client_handshake

        @sock.read_packet do |packet|
          if packet.ok?
            return
          elsif packet.err?
            code, message = read_error(packet)
            raise ConnectionError, "#{code}: #{message}"
          elsif packet.int == 0xFE # auth switch
            plugin = packet.nulstr
            data = packet.eof_str
            auth_switch(plugin, data)
          else
            raise "unkwown packet"
          end
        end
      end

      def server_handshake
        @sock.read_packet do |handshake|
          _protocol_version = handshake.int
          @server_version = handshake.nulstr
          _thread_id = handshake.int(4)
          auth_plugin_data = handshake.strn(8)
          handshake.strn(1)
          _capabilities = handshake.int(2)
          _character_set = handshake.int
          _status_flags = handshake.int(2)
          _capabilities2 = handshake.int(2)
          auth_plugin_data_len = handshake.int
          handshake.strn(10)
          @auth_plugin_data = auth_plugin_data + handshake.strn([13, auth_plugin_data_len - 8].max)
          @auth_plugin_name = handshake.nulstr
        end
      end

      def client_handshake
        @sock.write_packet do |packet|
          # TODO don't hardcode all this
          packet.int(4, 0x018aa200) # capabilities
          packet.int(4, 0xffffff) # max packet size
          packet.int(1, 0x2d) # charset
          packet.int(23, 0) # unused
          packet.nulstr(@options[:username] || "root")

          if @auth_plugin_name == "mysql_native_password" && password?
            packet.int(1, 20)
            packet.str(mysql_native_password(@auth_plugin_data))
          else
            packet.int(1, 0)
          end

          packet.nulstr(@auth_plugin_name)
        end
      end

      private

      def auth_switch(plugin, data)
        @sock.write_packet do |packet|
          if plugin == "mysql_native_password"
            packet.str(mysql_native_password(data)) if password?
          else
            raise "unknown auth plugin"
          end
        end

        @sock.read_packet do |packet|
          if packet.err?
            code, message = read_error(packet)
            raise ConnectionError, "#{code}: #{message}"
          end
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

      def read_error(packet)
        packet.int
        code = packet.int(2)
        packet.strn(1)
        packet.strn(5)
        message = packet.eof_str
        [code, message]
      end
    end
  end
end