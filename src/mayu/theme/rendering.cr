module Mayu
  class Theme
    # A counter image whose exact size is known before any byte is written, so a
    # response can declare its length and stream the image without buffering it.
    struct Rendering
      MAXIMUM_GLYPH_COUNT = 22
      BEFORE_HEIGHT       = %(<?xml version="1.0" encoding="UTF-8"?><svg height=")
      BEFORE_WIDTH        = %(" style="image-rendering: pixelated;" version="1.1" width=")
      BEFORE_DEFINITIONS  = %(" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">) +
                            "<title>Mayu</title><defs>"
      BEFORE_USES    = "</defs><g>"
      USE_CLOSING    = %("/>)
      SVG_CLOSING    = "</g></svg>"
      FIXED_BYTESIZE = BEFORE_HEIGHT.bytesize + BEFORE_WIDTH.bytesize + BEFORE_DEFINITIONS.bytesize +
                       BEFORE_USES.bytesize + SVG_CLOSING.bytesize

      getter bytesize : Int32
      @glyph_slots = StaticArray(UInt8, MAXIMUM_GLYPH_COUNT).new(0_u8)
      @glyph_count = 0
      @width = 0_i64
      @height = 0_i64

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

        @bytesize = FIXED_BYTESIZE + decimal_digit_count(@width) + decimal_digit_count(@height)

        each_definition { |glyph| @bytesize += glyph.definition.bytesize }
        each_use do |glyph, x|
          @bytesize += glyph.use_prefix.bytesize + decimal_digit_count(x) + USE_CLOSING.bytesize
        end
      end

      def to_s(io : IO) : Nil
        io << BEFORE_HEIGHT << @height << BEFORE_WIDTH << @width << BEFORE_DEFINITIONS
        each_definition { |glyph| io << glyph.definition }
        io << BEFORE_USES
        each_use { |glyph, x| io << glyph.use_prefix << x << USE_CLOSING }
        io << SVG_CLOSING
      end

      def to_s : String
        String.build(@bytesize) { |svg| to_s(svg) }
      end

      private def append_glyph(slot) : Nil
        return unless glyph = @theme.glyphs_by_slot[slot]

        @glyph_slots[@glyph_count] = slot.to_u8
        @glyph_count += 1
        @width += glyph.width
        @height = glyph.height if glyph.height > @height
      end

      private def each_glyph(&) : Nil
        @glyph_count.times do |glyph_index|
          yield @theme.glyphs_by_slot[@glyph_slots[glyph_index]].not_nil!, @glyph_slots[glyph_index]
        end
      end

      # Glyphs whose images are identical share an ID, so each image is defined
      # once in the order it first appears.
      private def each_definition(&) : Nil
        defined_slots = 0_u16

        each_glyph do |glyph, slot|
          definition_slot_bit = 1_u16 << @theme.definition_slots[slot]

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
