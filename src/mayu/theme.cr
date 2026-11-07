require "log"
require "./glyph_image"

module Mayu
  class Theme
    DIGIT_NAMES       = (0..9).map(&.to_s)
    GLYPH_NAMES       = DIGIT_NAMES + ["_start", "_end"]
    ADULT_NAME_SUFFIX = "-h"

    getter name : String

    def initialize(@name : String, @glyph_images : Hash(String, GlyphImage))
    end

    def self.load(themes_directory : String, name : String) : Theme?
      theme_directory = "#{themes_directory}/#{name}"
      glyph_images = {} of String => GlyphImage

      directory_entries(theme_directory).each do |file_name|
        name_parts = file_name.split('.')

        next unless name_parts.size == 2 && GLYPH_NAMES.includes?(name_parts[0])

        if glyph_image = GlyphImage.load("#{theme_directory}/#{file_name}")
          glyph_images[name_parts[0]] = glyph_image
        end
      end

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

    def render(number : Int64, padding : Int32) : String
      digit_names = number.to_s.rjust(padding, '0').chars.map(&.to_s)
      images = (["_start"] + digit_names + ["_end"]).compact_map { |glyph_name| @glyph_images[glyph_name]? }
      width = images.sum(0_i64, &.width)
      height = images.max_of?(&.height) || 0

      String.build do |svg|
        svg << %(<?xml version="1.0" encoding="UTF-8"?><svg height=") << height
        svg << %(" style="image-rendering: pixelated;" version="1.1" width=") << width
        svg << %(" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">)
        svg << "<title>Mayu</title><defs>"
        images.uniq(&.id).each { |image| svg << image.definition }
        svg << "</defs><g>"

        x = 0_i64

        images.each do |image|
          svg << %(<use xlink:href="#) << image.id << %(" x=") << x << %("/>)

          x += image.width
        end

        svg << "</g></svg>"
      end
    end
  end
end
