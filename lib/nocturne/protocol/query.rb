# frozen_string_literal: true

require "bigdecimal"
require "date"

class Nocturne
  module Protocol
    class Query
      def initialize(conn, options, flags)
        @conn = conn
        @options = options
        @flags = flags
      end

      def query(sql)
        @conn.begin_command

        @conn.write_packet do |packet|
          packet.int(1, Protocol::COM_QUERY)
          packet.str(sql)
        end

        column_count = 0
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
            raise Protocol.error(packet, QueryError)
          else
            column_count = packet.lenenc_int
          end
        end

        @columns = read_columns(column_count)
        fields = @columns.map(&:first)
        rows = read_rows(column_count)
        Result.new(fields, rows)
      end

      private

      def read_columns(column_count)
        columns = []

        i = 0
        while i < column_count
          @conn.read_packet do |column|
            column.skip(column.lenenc_int)
            column.skip(column.lenenc_int)
            column.skip(column.lenenc_int)
            column.skip(column.lenenc_int)
            name = column.lenenc_str
            column.skip(column.lenenc_int)
            column.lenenc_int
            charset = column.int16
            len = column.int32
            type = column.int8
            flags = column.int16
            decimals = column.int8

            columns << [name, charset, len, type, flags, decimals]
          end

          i += 1
        end

        columns
      end

      def read_rows(column_count)
        return [] if column_count.zero?

        rows = []

        more_rows = true
        while more_rows
          @conn.read_packet do |row|
            if row.eof?
              row.skip(1)
              @conn.update_status(
                warnings: row.int16,
                status_flags: row.int16
              )

              more_rows = false
              break
            end

            rows << read_row(column_count, row)
          end
        end

        rows
      end

      DECIMAL = 0
      TINY = 1
      SHORT = 2
      LONG = 3
      FLOAT = 4
      DOUBLE = 5
      TIMESTAMP = 7
      LONGLONG = 8
      INT24 = 9
      BIT = 0x10
      DATE = 0x0a
      TIME = 0x0b
      DATETIME = 0x0c
      YEAR = 0x0d
      NEWDECIMAL = 0xf6

      def read_row(column_count, row)
        result = []
        i = 0

        while i < column_count
          result << cast_value(row, @columns[i])
          i += 1
        end

        result
      end

      CHARSET_NONE = 0
      CHARSET_BIG5_CHINESE_CI = 1
      CHARSET_LATIN2_CZECH_CS = 2
      CHARSET_DEC8_SWEDISH_CI = 3
      CHARSET_CP850_GENERAL_CI = 4
      CHARSET_LATIN1_GERMAN1_CI = 5
      CHARSET_HP8_ENGLISH_CI = 6
      CHARSET_KOI8R_GENERAL_CI = 7
      CHARSET_LATIN1_SWEDISH_CI = 8
      CHARSET_LATIN2_GENERAL_CI = 9
      CHARSET_SWE7_SWEDISH_CI = 10
      CHARSET_ASCII_GENERAL_CI = 11
      CHARSET_UJIS_JAPANESE_CI = 12
      CHARSET_SJIS_JAPANESE_CI = 13
      CHARSET_CP1251_BULGARIAN_CI = 14
      CHARSET_LATIN1_DANISH_CI = 15
      CHARSET_HEBREW_GENERAL_CI = 16
      CHARSET_TIS620_THAI_CI = 18
      CHARSET_EUCKR_KOREAN_CI = 19
      CHARSET_LATIN7_ESTONIAN_CS = 20
      CHARSET_LATIN2_HUNGARIAN_CI = 21
      CHARSET_KOI8U_GENERAL_CI = 22
      CHARSET_CP1251_UKRAINIAN_CI = 23
      CHARSET_GB2312_CHINESE_CI = 24
      CHARSET_GREEK_GENERAL_CI = 25
      CHARSET_CP1250_GENERAL_CI = 26
      CHARSET_LATIN2_CROATIAN_CI = 27
      CHARSET_GBK_CHINESE_CI = 28
      CHARSET_CP1257_LITHUANIAN_CI = 29
      CHARSET_LATIN5_TURKISH_CI = 30
      CHARSET_LATIN1_GERMAN2_CI = 31
      CHARSET_ARMSCII8_GENERAL_CI = 32
      CHARSET_UTF8_GENERAL_CI = 33
      CHARSET_CP1250_CZECH_CS = 34
      CHARSET_UCS2_GENERAL_CI = 35
      CHARSET_CP866_GENERAL_CI = 36
      CHARSET_KEYBCS2_GENERAL_CI = 37
      CHARSET_MACCE_GENERAL_CI = 38
      CHARSET_MACROMAN_GENERAL_CI = 39
      CHARSET_CP852_GENERAL_CI = 40
      CHARSET_LATIN7_GENERAL_CI = 41
      CHARSET_LATIN7_GENERAL_CS = 42
      CHARSET_MACCE_BIN = 43
      CHARSET_CP1250_CROATIAN_CI = 44
      CHARSET_UTF8MB4_GENERAL_CI = 45
      CHARSET_UTF8MB4_BIN = 46
      CHARSET_LATIN1_BIN = 47
      CHARSET_LATIN1_GENERAL_CI = 48
      CHARSET_LATIN1_GENERAL_CS = 49
      CHARSET_CP1251_BIN = 50
      CHARSET_CP1251_GENERAL_CI = 51
      CHARSET_CP1251_GENERAL_CS = 52
      CHARSET_MACROMAN_BIN = 53
      CHARSET_UTF16_GENERAL_CI = 54
      CHARSET_UTF16_BIN = 55
      CHARSET_CP1256_GENERAL_CI = 57
      CHARSET_CP1257_BIN = 58
      CHARSET_CP1257_GENERAL_CI = 59
      CHARSET_UTF32_GENERAL_CI = 60
      CHARSET_UTF32_BIN = 61
      CHARSET_BINARY = 63
      CHARSET_ARMSCII8_BIN = 64
      CHARSET_ASCII_BIN = 65
      CHARSET_CP1250_BIN = 66
      CHARSET_CP1256_BIN = 67
      CHARSET_CP866_BIN = 68
      CHARSET_DEC8_BIN = 69
      CHARSET_GREEK_BIN = 70
      CHARSET_HEBREW_BIN = 71
      CHARSET_HP8_BIN = 72
      CHARSET_KEYBCS2_BIN = 73
      CHARSET_KOI8R_BIN = 74
      CHARSET_KOI8U_BIN = 75
      CHARSET_LATIN2_BIN = 77
      CHARSET_LATIN5_BIN = 78
      CHARSET_LATIN7_BIN = 79
      CHARSET_CP850_BIN = 80
      CHARSET_CP852_BIN = 81
      CHARSET_SWE7_BIN = 82
      CHARSET_UTF8_BIN = 83
      CHARSET_BIG5_BIN = 84
      CHARSET_EUCKR_BIN = 85
      CHARSET_GB2312_BIN = 86
      CHARSET_GBK_BIN = 87
      CHARSET_SJIS_BIN = 88
      CHARSET_TIS620_BIN = 89
      CHARSET_UCS2_BIN = 90
      CHARSET_UJIS_BIN = 91
      CHARSET_GEOSTD8_GENERAL_CI = 92
      CHARSET_GEOSTD8_BIN = 93
      CHARSET_LATIN1_SPANISH_CI = 94
      CHARSET_CP932_JAPANESE_CI = 95
      CHARSET_CP932_BIN = 96
      CHARSET_EUCJPMS_JAPANESE_CI = 97
      CHARSET_EUCJPMS_BIN = 98
      CHARSET_CP1250_POLISH_CI = 99
      CHARSET_UTF16_UNICODE_CI = 101
      CHARSET_UTF16_ICELANDIC_CI = 102
      CHARSET_UTF16_LATVIAN_CI = 103
      CHARSET_UTF16_ROMANIAN_CI = 104
      CHARSET_UTF16_SLOVENIAN_CI = 105
      CHARSET_UTF16_POLISH_CI = 106
      CHARSET_UTF16_ESTONIAN_CI = 107
      CHARSET_UTF16_SPANISH_CI = 108
      CHARSET_UTF16_SWEDISH_CI = 109
      CHARSET_UTF16_TURKISH_CI = 110
      CHARSET_UTF16_CZECH_CI = 111
      CHARSET_UTF16_DANISH_CI = 112
      CHARSET_UTF16_LITHUANIAN_CI = 113
      CHARSET_UTF16_SLOVAK_CI = 114
      CHARSET_UTF16_SPANISH2_CI = 115
      CHARSET_UTF16_ROMAN_CI = 116
      CHARSET_UTF16_PERSIAN_CI = 117
      CHARSET_UTF16_ESPERANTO_CI = 118
      CHARSET_UTF16_HUNGARIAN_CI = 119
      CHARSET_UTF16_SINHALA_CI = 120
      CHARSET_UCS2_UNICODE_CI = 128
      CHARSET_UCS2_ICELANDIC_CI = 129
      CHARSET_UCS2_LATVIAN_CI = 130
      CHARSET_UCS2_ROMANIAN_CI = 131
      CHARSET_UCS2_SLOVENIAN_CI = 132
      CHARSET_UCS2_POLISH_CI = 133
      CHARSET_UCS2_ESTONIAN_CI = 134
      CHARSET_UCS2_SPANISH_CI = 135
      CHARSET_UCS2_SWEDISH_CI = 136
      CHARSET_UCS2_TURKISH_CI = 137
      CHARSET_UCS2_CZECH_CI = 138
      CHARSET_UCS2_DANISH_CI = 139
      CHARSET_UCS2_LITHUANIAN_CI = 140
      CHARSET_UCS2_SLOVAK_CI = 141
      CHARSET_UCS2_SPANISH2_CI = 142
      CHARSET_UCS2_ROMAN_CI = 143
      CHARSET_UCS2_PERSIAN_CI = 144
      CHARSET_UCS2_ESPERANTO_CI = 145
      CHARSET_UCS2_HUNGARIAN_CI = 146
      CHARSET_UCS2_SINHALA_CI = 147
      CHARSET_UCS2_GENERAL_MYSQL500_CI = 159
      CHARSET_UTF32_UNICODE_CI = 160
      CHARSET_UTF32_ICELANDIC_CI = 161
      CHARSET_UTF32_LATVIAN_CI = 162
      CHARSET_UTF32_ROMANIAN_CI = 163
      CHARSET_UTF32_SLOVENIAN_CI = 164
      CHARSET_UTF32_POLISH_CI = 165
      CHARSET_UTF32_ESTONIAN_CI = 166
      CHARSET_UTF32_SPANISH_CI = 167
      CHARSET_UTF32_SWEDISH_CI = 168
      CHARSET_UTF32_TURKISH_CI = 169
      CHARSET_UTF32_CZECH_CI = 170
      CHARSET_UTF32_DANISH_CI = 171
      CHARSET_UTF32_LITHUANIAN_CI = 172
      CHARSET_UTF32_SLOVAK_CI = 173
      CHARSET_UTF32_SPANISH2_CI = 174
      CHARSET_UTF32_ROMAN_CI = 175
      CHARSET_UTF32_PERSIAN_CI = 176
      CHARSET_UTF32_ESPERANTO_CI = 177
      CHARSET_UTF32_HUNGARIAN_CI = 178
      CHARSET_UTF32_SINHALA_CI = 179
      CHARSET_UTF8_UNICODE_CI = 192
      CHARSET_UTF8_ICELANDIC_CI = 193
      CHARSET_UTF8_LATVIAN_CI = 194
      CHARSET_UTF8_ROMANIAN_CI = 195
      CHARSET_UTF8_SLOVENIAN_CI = 196
      CHARSET_UTF8_POLISH_CI = 197
      CHARSET_UTF8_ESTONIAN_CI = 198
      CHARSET_UTF8_SPANISH_CI = 199
      CHARSET_UTF8_SWEDISH_CI = 200
      CHARSET_UTF8_TURKISH_CI = 201
      CHARSET_UTF8_CZECH_CI = 202
      CHARSET_UTF8_DANISH_CI = 203
      CHARSET_UTF8_LITHUANIAN_CI = 204
      CHARSET_UTF8_SLOVAK_CI = 205
      CHARSET_UTF8_SPANISH2_CI = 206
      CHARSET_UTF8_ROMAN_CI = 207
      CHARSET_UTF8_PERSIAN_CI = 208
      CHARSET_UTF8_ESPERANTO_CI = 209
      CHARSET_UTF8_HUNGARIAN_CI = 210
      CHARSET_UTF8_SINHALA_CI = 211
      CHARSET_UTF8_GENERAL_MYSQL500_CI = 223
      CHARSET_UTF8MB4_UNICODE_CI = 224
      CHARSET_UTF8MB4_ICELANDIC_CI = 225
      CHARSET_UTF8MB4_LATVIAN_CI = 226
      CHARSET_UTF8MB4_ROMANIAN_CI = 227
      CHARSET_UTF8MB4_SLOVENIAN_CI = 228
      CHARSET_UTF8MB4_POLISH_CI = 229
      CHARSET_UTF8MB4_ESTONIAN_CI = 230
      CHARSET_UTF8MB4_SPANISH_CI = 231
      CHARSET_UTF8MB4_SWEDISH_CI = 232
      CHARSET_UTF8MB4_TURKISH_CI = 233
      CHARSET_UTF8MB4_CZECH_CI = 234
      CHARSET_UTF8MB4_DANISH_CI = 235
      CHARSET_UTF8MB4_LITHUANIAN_CI = 236
      CHARSET_UTF8MB4_SLOVAK_CI = 237
      CHARSET_UTF8MB4_SPANISH2_CI = 238
      CHARSET_UTF8MB4_ROMAN_CI = 239
      CHARSET_UTF8MB4_PERSIAN_CI = 240
      CHARSET_UTF8MB4_ESPERANTO_CI = 241
      CHARSET_UTF8MB4_HUNGARIAN_CI = 242
      CHARSET_UTF8MB4_SINHALA_CI = 243
      CHARSET_UTF8MB4_GERMAN2_CI = 244
      CHARSET_UTF8MB4_CROATIAN_CI = 245
      CHARSET_UTF8MB4_UNICODE_520_CI = 246
      CHARSET_UTF8MB4_VIETNAMESE_CI = 247
      CHARSET_GB18030_CHINESE_CI = 248
      CHARSET_GB18030_BIN_CI = 249
      CHARSET_GB18030_UNICODE_520_CI = 250
      CHARSET_UTF8MB4_0900_AI_CI = 255

      # TODO fill these in
      ENCODING_FOR_CHARSET = {
        CHARSET_NONE => nil,
        CHARSET_BIG5_CHINESE_CI => "",
        CHARSET_LATIN2_CZECH_CS => "",
        CHARSET_DEC8_SWEDISH_CI => "",
        CHARSET_CP850_GENERAL_CI => "",
        CHARSET_LATIN1_GERMAN1_CI => "",
        CHARSET_HP8_ENGLISH_CI => "",
        CHARSET_KOI8R_GENERAL_CI => "",
        CHARSET_LATIN1_SWEDISH_CI => "",
        CHARSET_LATIN2_GENERAL_CI => "",
        CHARSET_SWE7_SWEDISH_CI => "",
        CHARSET_ASCII_GENERAL_CI => "",
        CHARSET_UJIS_JAPANESE_CI => "",
        CHARSET_SJIS_JAPANESE_CI => "Shift_JIS",
        CHARSET_CP1251_BULGARIAN_CI => "",
        CHARSET_LATIN1_DANISH_CI => "",
        CHARSET_HEBREW_GENERAL_CI => "",
        CHARSET_TIS620_THAI_CI => "",
        CHARSET_EUCKR_KOREAN_CI => "",
        CHARSET_LATIN7_ESTONIAN_CS => "",
        CHARSET_LATIN2_HUNGARIAN_CI => "",
        CHARSET_KOI8U_GENERAL_CI => "",
        CHARSET_CP1251_UKRAINIAN_CI => "",
        CHARSET_GB2312_CHINESE_CI => "",
        CHARSET_GREEK_GENERAL_CI => "",
        CHARSET_CP1250_GENERAL_CI => "",
        CHARSET_LATIN2_CROATIAN_CI => "",
        CHARSET_GBK_CHINESE_CI => "",
        CHARSET_CP1257_LITHUANIAN_CI => "",
        CHARSET_LATIN5_TURKISH_CI => "",
        CHARSET_LATIN1_GERMAN2_CI => "",
        CHARSET_ARMSCII8_GENERAL_CI => "",
        CHARSET_UTF8_GENERAL_CI => "",
        CHARSET_CP1250_CZECH_CS => "",
        CHARSET_UCS2_GENERAL_CI => "",
        CHARSET_CP866_GENERAL_CI => "",
        CHARSET_KEYBCS2_GENERAL_CI => "",
        CHARSET_MACCE_GENERAL_CI => "",
        CHARSET_MACROMAN_GENERAL_CI => "",
        CHARSET_CP852_GENERAL_CI => "",
        CHARSET_LATIN7_GENERAL_CI => "",
        CHARSET_LATIN7_GENERAL_CS => "",
        CHARSET_MACCE_BIN => "",
        CHARSET_CP1250_CROATIAN_CI => "",
        CHARSET_UTF8MB4_GENERAL_CI => "UTF-8",
        CHARSET_UTF8MB4_BIN => "",
        CHARSET_LATIN1_BIN => "",
        CHARSET_LATIN1_GENERAL_CI => "",
        CHARSET_LATIN1_GENERAL_CS => "",
        CHARSET_CP1251_BIN => "",
        CHARSET_CP1251_GENERAL_CI => "",
        CHARSET_CP1251_GENERAL_CS => "",
        CHARSET_MACROMAN_BIN => "",
        CHARSET_UTF16_GENERAL_CI => "",
        CHARSET_UTF16_BIN => "",
        CHARSET_CP1256_GENERAL_CI => "",
        CHARSET_CP1257_BIN => "",
        CHARSET_CP1257_GENERAL_CI => "",
        CHARSET_UTF32_GENERAL_CI => "",
        CHARSET_UTF32_BIN => "",
        CHARSET_BINARY => "BINARY",
        CHARSET_ARMSCII8_BIN => "",
        CHARSET_ASCII_BIN => "",
        CHARSET_CP1250_BIN => "",
        CHARSET_CP1256_BIN => "",
        CHARSET_CP866_BIN => "",
        CHARSET_DEC8_BIN => "",
        CHARSET_GREEK_BIN => "",
        CHARSET_HEBREW_BIN => "",
        CHARSET_HP8_BIN => "",
        CHARSET_KEYBCS2_BIN => "",
        CHARSET_KOI8R_BIN => "",
        CHARSET_KOI8U_BIN => "",
        CHARSET_LATIN2_BIN => "",
        CHARSET_LATIN5_BIN => "",
        CHARSET_LATIN7_BIN => "",
        CHARSET_CP850_BIN => "",
        CHARSET_CP852_BIN => "",
        CHARSET_SWE7_BIN => "",
        CHARSET_UTF8_BIN => "",
        CHARSET_BIG5_BIN => "",
        CHARSET_EUCKR_BIN => "",
        CHARSET_GB2312_BIN => "",
        CHARSET_GBK_BIN => "",
        CHARSET_SJIS_BIN => "",
        CHARSET_TIS620_BIN => "",
        CHARSET_UCS2_BIN => "",
        CHARSET_UJIS_BIN => "",
        CHARSET_GEOSTD8_GENERAL_CI => "",
        CHARSET_GEOSTD8_BIN => "",
        CHARSET_LATIN1_SPANISH_CI => "",
        CHARSET_CP932_JAPANESE_CI => "",
        CHARSET_CP932_BIN => "",
        CHARSET_EUCJPMS_JAPANESE_CI => "",
        CHARSET_EUCJPMS_BIN => "",
        CHARSET_CP1250_POLISH_CI => "",
        CHARSET_UTF16_UNICODE_CI => "",
        CHARSET_UTF16_ICELANDIC_CI => "",
        CHARSET_UTF16_LATVIAN_CI => "",
        CHARSET_UTF16_ROMANIAN_CI => "",
        CHARSET_UTF16_SLOVENIAN_CI => "",
        CHARSET_UTF16_POLISH_CI => "",
        CHARSET_UTF16_ESTONIAN_CI => "",
        CHARSET_UTF16_SPANISH_CI => "",
        CHARSET_UTF16_SWEDISH_CI => "",
        CHARSET_UTF16_TURKISH_CI => "",
        CHARSET_UTF16_CZECH_CI => "",
        CHARSET_UTF16_DANISH_CI => "",
        CHARSET_UTF16_LITHUANIAN_CI => "",
        CHARSET_UTF16_SLOVAK_CI => "",
        CHARSET_UTF16_SPANISH2_CI => "",
        CHARSET_UTF16_ROMAN_CI => "",
        CHARSET_UTF16_PERSIAN_CI => "",
        CHARSET_UTF16_ESPERANTO_CI => "",
        CHARSET_UTF16_HUNGARIAN_CI => "",
        CHARSET_UTF16_SINHALA_CI => "",
        CHARSET_UCS2_UNICODE_CI => "",
        CHARSET_UCS2_ICELANDIC_CI => "",
        CHARSET_UCS2_LATVIAN_CI => "",
        CHARSET_UCS2_ROMANIAN_CI => "",
        CHARSET_UCS2_SLOVENIAN_CI => "",
        CHARSET_UCS2_POLISH_CI => "",
        CHARSET_UCS2_ESTONIAN_CI => "",
        CHARSET_UCS2_SPANISH_CI => "",
        CHARSET_UCS2_SWEDISH_CI => "",
        CHARSET_UCS2_TURKISH_CI => "",
        CHARSET_UCS2_CZECH_CI => "",
        CHARSET_UCS2_DANISH_CI => "",
        CHARSET_UCS2_LITHUANIAN_CI => "",
        CHARSET_UCS2_SLOVAK_CI => "",
        CHARSET_UCS2_SPANISH2_CI => "",
        CHARSET_UCS2_ROMAN_CI => "",
        CHARSET_UCS2_PERSIAN_CI => "",
        CHARSET_UCS2_ESPERANTO_CI => "",
        CHARSET_UCS2_HUNGARIAN_CI => "",
        CHARSET_UCS2_SINHALA_CI => "",
        CHARSET_UCS2_GENERAL_MYSQL500_CI => "",
        CHARSET_UTF32_UNICODE_CI => "",
        CHARSET_UTF32_ICELANDIC_CI => "",
        CHARSET_UTF32_LATVIAN_CI => "",
        CHARSET_UTF32_ROMANIAN_CI => "",
        CHARSET_UTF32_SLOVENIAN_CI => "",
        CHARSET_UTF32_POLISH_CI => "",
        CHARSET_UTF32_ESTONIAN_CI => "",
        CHARSET_UTF32_SPANISH_CI => "",
        CHARSET_UTF32_SWEDISH_CI => "",
        CHARSET_UTF32_TURKISH_CI => "",
        CHARSET_UTF32_CZECH_CI => "",
        CHARSET_UTF32_DANISH_CI => "",
        CHARSET_UTF32_LITHUANIAN_CI => "",
        CHARSET_UTF32_SLOVAK_CI => "",
        CHARSET_UTF32_SPANISH2_CI => "",
        CHARSET_UTF32_ROMAN_CI => "",
        CHARSET_UTF32_PERSIAN_CI => "",
        CHARSET_UTF32_ESPERANTO_CI => "",
        CHARSET_UTF32_HUNGARIAN_CI => "",
        CHARSET_UTF32_SINHALA_CI => "",
        CHARSET_UTF8_UNICODE_CI => "",
        CHARSET_UTF8_ICELANDIC_CI => "",
        CHARSET_UTF8_LATVIAN_CI => "",
        CHARSET_UTF8_ROMANIAN_CI => "",
        CHARSET_UTF8_SLOVENIAN_CI => "",
        CHARSET_UTF8_POLISH_CI => "",
        CHARSET_UTF8_ESTONIAN_CI => "",
        CHARSET_UTF8_SPANISH_CI => "",
        CHARSET_UTF8_SWEDISH_CI => "",
        CHARSET_UTF8_TURKISH_CI => "",
        CHARSET_UTF8_CZECH_CI => "",
        CHARSET_UTF8_DANISH_CI => "",
        CHARSET_UTF8_LITHUANIAN_CI => "",
        CHARSET_UTF8_SLOVAK_CI => "",
        CHARSET_UTF8_SPANISH2_CI => "",
        CHARSET_UTF8_ROMAN_CI => "",
        CHARSET_UTF8_PERSIAN_CI => "",
        CHARSET_UTF8_ESPERANTO_CI => "",
        CHARSET_UTF8_HUNGARIAN_CI => "",
        CHARSET_UTF8_SINHALA_CI => "",
        CHARSET_UTF8_GENERAL_MYSQL500_CI => "",
        CHARSET_UTF8MB4_UNICODE_CI => "",
        CHARSET_UTF8MB4_ICELANDIC_CI => "",
        CHARSET_UTF8MB4_LATVIAN_CI => "",
        CHARSET_UTF8MB4_ROMANIAN_CI => "",
        CHARSET_UTF8MB4_SLOVENIAN_CI => "",
        CHARSET_UTF8MB4_POLISH_CI => "",
        CHARSET_UTF8MB4_ESTONIAN_CI => "",
        CHARSET_UTF8MB4_SPANISH_CI => "",
        CHARSET_UTF8MB4_SWEDISH_CI => "",
        CHARSET_UTF8MB4_TURKISH_CI => "",
        CHARSET_UTF8MB4_CZECH_CI => "",
        CHARSET_UTF8MB4_DANISH_CI => "",
        CHARSET_UTF8MB4_LITHUANIAN_CI => "",
        CHARSET_UTF8MB4_SLOVAK_CI => "",
        CHARSET_UTF8MB4_SPANISH2_CI => "",
        CHARSET_UTF8MB4_ROMAN_CI => "",
        CHARSET_UTF8MB4_PERSIAN_CI => "",
        CHARSET_UTF8MB4_ESPERANTO_CI => "",
        CHARSET_UTF8MB4_HUNGARIAN_CI => "",
        CHARSET_UTF8MB4_SINHALA_CI => "",
        CHARSET_UTF8MB4_GERMAN2_CI => "",
        CHARSET_UTF8MB4_CROATIAN_CI => "",
        CHARSET_UTF8MB4_UNICODE_520_CI => "",
        CHARSET_UTF8MB4_VIETNAMESE_CI => "",
        CHARSET_GB18030_CHINESE_CI => "",
        CHARSET_GB18030_BIN_CI => "",
        CHARSET_GB18030_UNICODE_520_CI => "",
        CHARSET_UTF8MB4_0900_AI_CI => ""
      }

      def cast_value(row, column)
        return if row.nil?
        return row.lenenc_str if (@flags & QUERY_FLAGS_CAST).zero?

        _name, charset, len, type, _flags, decimals = column

        case type
        when BIT
          if len == 1 && !(@flags & QUERY_FLAGS_CAST_BOOLEANS).zero?
            raise "unexpected int" if row.lenenc_int != 1
            !row.int8.zero?
          else
            row.lenenc_str
          end
        when TINY
          if len == 1 && !(@flags & QUERY_FLAGS_CAST_BOOLEANS).zero?
            raise "unexpected int" if row.lenenc_int != 1
            !(row.strn(1) == "0")
          else
            row.lenenc_str.to_i
          end
        when SHORT, LONG, LONGLONG, INT24, YEAR
          row.lenenc_str.to_i
        when DECIMAL, NEWDECIMAL
          if decimals.zero? && (@flags & QUERY_FLAGS_CAST_ALL_DECIMALS_TO_BIGDECIMALS).zero?
            Integer(row.lenenc_str)
          else
            BigDecimal(row.lenenc_str)
          end
        when FLOAT, DOUBLE
          Float(row.lenenc_str)
        when TIMESTAMP, DATETIME
          if (@flags & QUERY_FLAGS_LOCAL_TIMEZONE).zero?
            Time.new(row.lenenc_str, in: "UTC")
          else
            Time.new(row.lenenc_str)
          end
        when TIME
          if (@flags & QUERY_FLAGS_LOCAL_TIMEZONE).zero?
            Time.new("2000-01-01 " + row.lenenc_str, in: "UTC")
          else
            Time.new("2000-01-01 " + row.lenenc_str)
          end
        when DATE
          Date.strptime(row.lenenc_str, "%Y-%m-%d")
        else
          row.lenenc_str.force_encoding(ENCODING_FOR_CHARSET[charset])
        end
      end
    end
  end
end
