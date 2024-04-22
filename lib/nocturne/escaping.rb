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

    SERVER_STATUS_NO_BACKSLASH_ESCAPES = 0x0200

    def escape(str)
      encoding = str.encoding

      if !encoding.ascii_compatible?
        raise Encoding::CompatibilityError, "input string must be ASCII-compatible"
      end

      res = "".b

      i = 0
      j = str.length
      while i < j
        byte = str.getbyte(i)

        if (@conn.status_flags & SERVER_STATUS_NO_BACKSLASH_ESCAPES).zero? && (escaped = ESCAPES[byte])
          res << "\\"
          res << escaped
        elsif byte == SINGLE_QUOTE
          res << "''"
        else
          res << byte
        end

        i += 1
      end

      res.force_encoding(encoding)
    end
  end
end
