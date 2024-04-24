# frozen_string_literal: true

class Nocturne
  module Escaping
    ESCAPES = {
      "\"".ord => "\"",
      "\0".ord => "0",
      "'".ord => "'",
      "\\".ord => "\\",
      "\n".ord => "n",
      "\r".ord => "r",
      "\x1A".ord => "Z"
    }
    SINGLE_QUOTE = "'".ord

    def escape(str)
      encoding = str.encoding

      if !encoding.ascii_compatible?
        raise Encoding::CompatibilityError, "input string must be ASCII-compatible"
      end

      res = str.dup
      pos = 0

      i = 0
      j = str.length
      while i < j
        byte = str.getbyte(i)

        if !@conn.status_flag?(Protocol::SERVER_STATUS_NO_BACKSLASH_ESCAPES)
          if (escaped = ESCAPES[byte])
            res.bytesplice(pos, 0, "\\")
            pos += 1
            res[pos] = escaped
          end
        elsif byte == SINGLE_QUOTE
          res.bytesplice(pos, 0, "'")
          pos += 1
        end

        i += 1
        pos += 1
      end

      res
    end
  end
end
