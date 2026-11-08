require "./theme"

# Prints the themes in the given directory as a Crystal hash literal of encoded
# glyph images, which `EMBEDDED_THEMES` compiles into the binary. Standard output
# is the generated code, so log messages go to standard error.
Log.setup(:info, Log::IOBackend.new(STDERR))

themes_directory = ARGV[0]
theme_names = Mayu::Theme.directory_entries(themes_directory).sort!

if theme_names.empty?
  puts "{} of String => Hash(String, Mayu::GlyphImage)"
  exit
end

puts "{"

theme_names.each do |theme_name|
  glyph_images = Mayu::Theme.load_glyph_images(themes_directory, theme_name)

  if glyph_images.empty?
    puts "  #{theme_name.inspect} => {} of String => Mayu::GlyphImage,"

    next
  end

  puts "  #{theme_name.inspect} => {"

  glyph_images.each do |glyph_name, glyph_image|
    puts "    #{glyph_name.inspect} => Mayu::GlyphImage.new(id: #{glyph_image.id.inspect}, " \
         "definition: #{glyph_image.definition.inspect}, width: #{glyph_image.width}_i64, " \
         "height: #{glyph_image.height}_i64),"
  end

  puts "  },"
end

puts "}"
