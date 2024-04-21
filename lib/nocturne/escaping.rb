# frozen_string_literal: true

class Nocturne
  module Escaping
    ESCAPES = {
      "\"" => "\"",
      "\0" => "0",
      "'" => "'",
      "\\" => "\\",
      "\n" => "n",
      "\r" => "r",
      "\x1A" => "Z"
    }

    SERVER_STATUS_NO_BACKSLASH_ESCAPES = 0x0200

    def escape(str)
      encoding = str.encoding

      if !encoding.ascii_compatible?
        raise Encoding::CompatibilityError, "input string must be ASCII-compatible"
      end

      res = String.new("", encoding: encoding)

      i = 0
      j = str.length
      while i < j
        chr = str[i]

        if (@conn.status_flags & SERVER_STATUS_NO_BACKSLASH_ESCAPES).zero? && (escaped = ESCAPES[chr])
          res << "\\"
          res << escaped
        elsif chr == "'"
          res << "''"
        else
          res << chr
        end

        i += 1
      end

      res
    end
  end
end
