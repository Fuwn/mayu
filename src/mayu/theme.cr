require "log"
require "./glyph_image"

module Mayu
  class Theme
    DIGIT_NAMES       = (0..9).map(&.to_s)
    GLYPH_NAMES       = DIGIT_NAMES + ["_start", "_end"]
    ADULT_NAME_SUFFIX = "-h"

    START_SLOT = 10
    END_SLOT   = 11
    SLOT_COUNT = 12

    getter name : String
    getter glyphs_by_slot : StaticArray(GlyphImage?, SLOT_COUNT)
    getter first_slots_with_same_image : StaticArray(Int32, SLOT_COUNT)

    def initialize(@name : String, glyph_images : Hash(String, GlyphImage))
      @glyphs_by_slot = StaticArray(GlyphImage?, SLOT_COUNT).new do |slot|
        glyph_images[GLYPH_NAMES[slot]]?
      end
      @first_slots_with_same_image = StaticArray(Int32, SLOT_COUNT).new do |slot|
        image_id = @glyphs_by_slot[slot].try(&.id)

        (0...slot).find(slot) { |earlier_slot| image_id && @glyphs_by_slot[earlier_slot].try(&.id) == image_id }
      end
    end

    def self.load_glyph_images(themes_directory : String, name : String) : Hash(String, GlyphImage)
      theme_directory = "#{themes_directory}/#{name}"
      glyph_images = {} of String => GlyphImage

      directory_entries(theme_directory).sort!.each do |file_name|
        name_parts = file_name.split('.')

        next unless name_parts.size == 2 && GLYPH_NAMES.includes?(name_parts[0])

        if glyph_image = GlyphImage.load("#{theme_directory}/#{file_name}")
          glyph_images[name_parts[0]] = glyph_image
        end
      end

      glyph_images
    end

    def self.validated(name : String, glyph_images : Hash(String, GlyphImage)) : Theme?
      if glyph_images.empty?
        Log.error { "Ignoring #{name}: no glyphs found" }

        return
      end

      missing_digit_names = DIGIT_NAMES.reject { |digit_name| glyph_images.has_key?(digit_name) }

      unless missing_digit_names.empty?
        Log.warn { "Theme #{name} is missing digit glyphs: #{missing_digit_names.join(", ")}" }
      end

      new(name, glyph_images)
    end

    def self.directory_entries(path : String) : Array(String)
      Dir.children(path)
    rescue error : File::Error
      Log.error { "Failed to read theme directory #{path}: #{error.message}" }

      [] of String
    end

    def adult? : Bool
      @name.ends_with?(ADULT_NAME_SUFFIX)
    end

    def rendering(number : Int64, padding : Int32) : Rendering
      Rendering.new(self, number, padding)
    end
  end
end

require "./theme/rendering"
