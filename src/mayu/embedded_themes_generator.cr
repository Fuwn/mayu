require "./theme"

# Standard output is the generated code, so log messages go to standard error.
Log.setup(:info, Log::IOBackend.new(STDERR))

# Every "#" is escaped so the literal can never interpolate.
def byte_literal(bytes : Bytes) : String
  String.build(bytes.size * 3) do |literal|
    literal << '"'

    bytes.each do |byte|
      if 0x20 <= byte <= 0x7e && !byte.unsafe_chr.in?('"', '\\', '#')
        literal << byte.unsafe_chr
      else
        literal << "\\x"
        byte.to_s(literal, 16, precision: 2)
      end
    end

    literal << '"'
  end
end

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
    puts "    #{glyph_name.inspect} => Mayu::GlyphImage.new(#{glyph_image.id.inspect}, " \
         "#{glyph_image.definition.inspect}, #{glyph_image.width}_i64, #{glyph_image.height}_i64, " \
         "#{byte_literal(glyph_image.compressed_definition)}.to_slice, #{glyph_image.definition_checksum}_u32),"
  end

  puts "  },"
end

puts "}"
