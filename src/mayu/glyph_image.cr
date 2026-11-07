require "base64"
require "digest/sha256"
require "log"

module Mayu
  struct GlyphImage
    PNG_SIGNATURE = Bytes[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    private record Header, width : Int64, height : Int64, format : String

    getter id : String
    getter definition : String
    getter width : Int64
    getter height : Int64

    def initialize(@id, @definition, @width, @height)
    end

    def self.load(path : String) : GlyphImage?
      image_data = File.open(path, &.getb_to_end)

      if header = read_header(image_data)
        from_image_data(image_data, header)
      else
        Log.error { "Failed to load image #{path}: Unsupported image format" }

        nil
      end
    rescue error : File::Error
      Log.error { "Failed to read image #{path}: #{error.message}" }

      nil
    end

    private def self.read_header(image_data : Bytes) : Header?
      if image_data.size >= 24 && image_data[0, 8] == PNG_SIGNATURE && image_data[12, 4] == "IHDR".to_slice
        width = IO::ByteFormat::BigEndian.decode(UInt32, image_data[16, 4])
        height = IO::ByteFormat::BigEndian.decode(UInt32, image_data[20, 4])

        Header.new(width.to_i64, height.to_i64, "png")
      elsif image_data.size >= 10 && image_data[0, 3] == "GIF".to_slice
        width = IO::ByteFormat::LittleEndian.decode(UInt16, image_data[6, 2])
        height = IO::ByteFormat::LittleEndian.decode(UInt16, image_data[8, 2])

        Header.new(width.to_i64, height.to_i64, "gif")
      end
    end

    private def self.from_image_data(image_data, header) : GlyphImage
      image_id = "mayu-#{Digest::SHA256.hexdigest(image_data)[0, 16].upcase}"
      data_url = "data:image/#{header.format};base64,#{Base64.strict_encode(image_data)}"
      definition = %(<image id="#{image_id}" height="#{header.height}" width="#{header.width}" ) \
                   %(xlink:href="#{data_url}"/>)

      new(
        id: image_id,
        definition: definition,
        width: header.width,
        height: header.height,
      )
    end
  end
end
