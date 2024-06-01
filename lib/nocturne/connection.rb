# frozen_string_literal:true

class Nocturne
  class Connection
    attr_reader :status_flags, :warnings, :affected_rows, :last_insert_id, :last_gtid

    def initialize(options)
      @sock = Nocturne::Socket.new(options)
      @write = Write::Packet.new
      @read = Read::Packet.new
      @read_buffer = "".b
      @read_pos = 0
      @read_len = 0
      @next_sequence = 0
      @options = options

      @status_flags = nil
      @warnings = nil
      @affected_rows = nil
      @last_insert_id = nil
      @last_gtid = nil
    end

    def begin_command
      raise ConnectionClosed if closed?
      raise "unread data" unless buffer_fully_read?
      raise "unwritten data" unless @write.empty?
      @next_sequence = 0
    end

    def write_packet(&blk)
      @write.build(@next_sequence, @options, &blk)

      written = 0
      while (data = @write.data(written))
        written += @sock.sendmsg(data)
      end

      @next_sequence = (@write.sequence + 1) % 256
    ensure
      @write.reset
    end

    def read_packet
      @read.reset

      loop do
        @read.new_packet

        until @read.complete?
          if buffer_fully_read?
            @sock.recv(@read_buffer)
            @read_len = @read_buffer.length
            @read_pos = 0
          end

          @read_pos += @read.parse_fragment(@read_buffer, @read_len, @read_pos)
        end

        raise "sequence out of order" if @read.sequence != @next_sequence
        @next_sequence = (@read.sequence + 1) % 256

        break unless @read.continues?
      end

      payload = @read.payload

      if payload.ok?
        payload.skip(1)
        @affected_rows = payload.lenenc_int
        @last_insert_id = payload.lenenc_int
        @status_flags = payload.int16
        @warnings = payload.int16

        if status_flag?(Protocol::SERVER_STATUS_SESSION_STATE_CHANGED)
          payload.skip(payload.lenenc_int)
          payload.int8

          until payload.fully_read?
            type = payload.int8
            info = payload.lenenc_str

            if type == Protocol::SESSION_TRACK_GTIDS
              gtid_payload = Read::Payload.new
              gtid_payload.fragments = [info]
              gtid_payload.int8
              @last_gtid = gtid_payload.lenenc_str
            end
          end
        end
      end

      yield payload if block_given?
    end

    def update_status(status_flags:, warnings: nil)
      @status_flags = status_flags
      @warnings = warnings
      @affected_rows = nil
      @last_insert_id = nil
    end

    def status_flag?(flag)
      !(status_flags & flag).zero?
    end

    def upgrade
      @sock = @sock.ssl_sock
    end

    def close
      @sock.close
      @closed = true
    end

    def closed?
      @closed
    end

    private

    def buffer_fully_read?
      @read_len == @read_pos
    end
  end
end
