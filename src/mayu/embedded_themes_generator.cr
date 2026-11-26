require "./theme"

# Standard output is the generated code, so log messages go to standard error.
Log.setup(:info, Log::IOBackend.new(STDERR))

themes_directory = ARGV[0]

puts "{"

Mayu::Theme.directory_entries(themes_directory).sort!.each do |theme_name|
  puts "  #{theme_name.inspect} => {"

  Mayu::Theme.load_glyph_images(themes_directory, theme_name).each do |glyph_name, glyph_image|
    # `String#inspect` escapes interpolation and writes bytes that are not valid
    # UTF-8 as `\xNN`, so the literal holds the compressed bytes exactly.
    puts "    #{glyph_name.inspect} => Mayu::GlyphImage.new(#{glyph_image.id.inspect}, " \
         "#{glyph_image.definition.inspect}, #{glyph_image.width}_i64, #{glyph_image.height}_i64, " \
         "#{String.new(glyph_image.compressed_definition).inspect}.to_slice, #{glyph_image.definition_checksum}_u32),"
  end

  puts "  } of String => Mayu::GlyphImage,"
end

puts "} of String => Hash(String, Mayu::GlyphImage)"
