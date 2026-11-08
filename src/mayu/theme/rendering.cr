require "digest/crc32"

module Mayu
  class Theme
    struct Rendering
      MAXIMUM_BUFFERED_BYTESIZE = 65_536
      MAXIMUM_GLYPH_COUNT       =     22
      BEFORE_HEIGHT             = %(<?xml version="1.0" encoding="UTF-8"?><svg height=")
      BEFORE_WIDTH              = %(" style="image-rendering: pixelated;" version="1.1" width=")
      BEFORE_DEFINITIONS        = %(" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">) +
                                  "<title>Mayu</title><defs>"
      BEFORE_USES                  = "</defs><g>"
      USE_CLOSING                  = %("/>)
      SVG_CLOSING                  = "</g></svg>"
      GZIP_HEADER                  = Bytes[0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff]
      FINAL_EMPTY_BLOCK            = Bytes[1, 0, 0, 0xff, 0xff]
      STORED_BLOCK_HEADER_BYTESIZE = 5
      GZIP_TRAILER_BYTESIZE        = 8

      getter bytesize : Int32
      @glyph_slots = StaticArray(UInt8, MAXIMUM_GLYPH_COUNT).new(0_u8)
      @glyph_count = 0
      @width = 0_i64
      @height = 0_i64
      @opening_bytesize = 0
      @closing_bytesize = 0

      def initialize(@theme : Theme, number : Int64, padding : Int32)
        digits = StaticArray(UInt8, 20).new(0_u8)
        digit_count = 0
        remaining_number = number.to_u64

        loop do
          digits[digit_count] = (remaining_number % 10).to_u8
          digit_count += 1
          remaining_number //= 10

          break if remaining_number.zero?
        end

        append_glyph(START_SLOT)
        (padding - digit_count).times { append_glyph(0) }
        (digit_count - 1).downto(0) { |digit_index| append_glyph(digits[digit_index]) }
        append_glyph(END_SLOT)

        @opening_bytesize = BEFORE_HEIGHT.bytesize + decimal_digit_count(@height) + BEFORE_WIDTH.bytesize +
                            decimal_digit_count(@width) + BEFORE_DEFINITIONS.bytesize
        @closing_bytesize = BEFORE_USES.bytesize + SVG_CLOSING.bytesize

        each_use do |glyph, x|
          @closing_bytesize += glyph.use_prefix.bytesize + decimal_digit_count(x) + USE_CLOSING.bytesize
        end

        @bytesize = @opening_bytesize + @closing_bytesize

        each_definition { |glyph| @bytesize += glyph.definition.bytesize }
      end

      def streamed? : Bool
        @bytesize > MAXIMUM_BUFFERED_BYTESIZE
      end

      def to_s(io : IO) : Nil
        write_opening(io)
        each_definition { |glyph| io << glyph.definition }
        write_closing(io)
      end

      def to_s : String
        String.build(@bytesize) { |svg| to_s(svg) }
      end

      def compressible? : Bool
        return false unless streamed?

        each_definition { |glyph| return false unless glyph.compressed_definition }

        true
      end

      def gzip_bytesize : Int32
        compressed_bytesize = 0

        each_definition { |glyph| compressed_bytesize += glyph.compressed_definition.not_nil!.size }

        GZIP_HEADER.size + STORED_BLOCK_HEADER_BYTESIZE + @opening_bytesize + compressed_bytesize +
          STORED_BLOCK_HEADER_BYTESIZE + @closing_bytesize + FINAL_EMPTY_BLOCK.size + GZIP_TRAILER_BYTESIZE
      end

      # Writes gzip assembled from definitions deflated at compile time. Each ends
      # on a byte boundary, so the dynamic opening and closing go between them as
      # stored blocks, and the checksum combines the definitions' own checksums.
      def write_gzip(io : IO) : Nil
        opening = String.build(@opening_bytesize) { |text| write_opening(text) }
        closing = String.build(@closing_bytesize) { |text| write_closing(text) }
        checksum = Digest::CRC32.checksum(opening)

        io.write(GZIP_HEADER)
        write_stored_block(io, opening)
        each_definition do |glyph|
          io.write(glyph.compressed_definition.not_nil!)
          checksum = Digest::CRC32.combine(checksum, glyph.definition_checksum, glyph.definition.bytesize)
        end
        write_stored_block(io, closing)
        io.write(FINAL_EMPTY_BLOCK)

        checksum = Digest::CRC32.update(closing, checksum)

        io.write_bytes(checksum, IO::ByteFormat::LittleEndian)
        io.write_bytes(@bytesize.to_u32, IO::ByteFormat::LittleEndian)
      end

      private def append_glyph(slot) : Nil
        return unless glyph = @theme.glyphs_by_slot[slot]

        @glyph_slots[@glyph_count] = slot.to_u8
        @glyph_count += 1
        @width += glyph.width
        @height = glyph.height if glyph.height > @height
      end

      private def write_opening(io) : Nil
        io << BEFORE_HEIGHT << @height << BEFORE_WIDTH << @width << BEFORE_DEFINITIONS
      end

      private def write_closing(io) : Nil
        io << BEFORE_USES
        each_use { |glyph, x| io << glyph.use_prefix << x << USE_CLOSING }
        io << SVG_CLOSING
      end

      private def write_stored_block(io, text) : Nil
        io.write_byte(0_u8)
        io.write_bytes(text.bytesize.to_u16, IO::ByteFormat::LittleEndian)
        io.write_bytes(~text.bytesize.to_u16, IO::ByteFormat::LittleEndian)
        io << text
      end

      private def each_glyph(&) : Nil
        @glyph_count.times do |glyph_index|
          yield @theme.glyphs_by_slot[@glyph_slots[glyph_index]].not_nil!, @glyph_slots[glyph_index]
        end
      end

      private def each_definition(&) : Nil
        defined_slots = 0_u16

        each_glyph do |glyph, slot|
          definition_slot_bit = 1_u16 << @theme.first_slots_with_same_image[slot]

          next unless defined_slots & definition_slot_bit == 0

          defined_slots |= definition_slot_bit

          yield glyph
        end
      end

      private def each_use(&) : Nil
        x = 0_i64

        each_glyph do |glyph|
          yield glyph, x

          x += glyph.width
        end
      end

      private def decimal_digit_count(value : Int64) : Int32
        digit_count = 1

        while value >= 10
          value //= 10
          digit_count += 1
        end

        digit_count
      end
    end
  end
end
