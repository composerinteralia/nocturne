# frozen_string_literal: true

class Nocturne
  module Escaping
    def escape(str)
      encoding = str.encoding

      unless encoding.ascii_compatible?
        raise ::Encoding::CompatibilityError, "input string must be ASCII-compatible"
      end

      res = str.dup

      if @conn.status_flag?(Protocol::SERVER_STATUS_NO_BACKSLASH_ESCAPES)
        idx = 0
        while (idx = res.index("'", idx))
          res.bytesplice(idx, 0, "'")
          idx += 2
        end
      else
        i = 0
        len = str.length
        while i < len
          byte = res.getbyte(i)

          escaped = case byte
          when 0 then "\\0"
          when 10 then "\\n"
          when 13 then "\\r"
          when 26 then "\\Z"
          when 34 then "\\\""
          when 39 then "\\'"
          when 92 then "\\\\"
          else
            i += 1
            next
          end

          res.bytesplice(i, 1, escaped)
          i += 2
          len += 1
        end
      end

      res
    end
  end
end
