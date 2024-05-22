pub type ImageInformation {
  ImageInformation(width: Int, height: Int, extension: String)
}

pub fn get_image_information(image) {
  case image {
    <<0x89, "PNG\r\n":utf8, 0x1A, "\n":utf8, _rest:bits>> ->
      parse_png_chunks(image, 8)
    <<
      "GIF":utf8,
      _version:unsigned-24,
      width:little-16,
      height:little-16,
      _rest:bits,
    >> -> Ok(ImageInformation(width, height, "gif"))
    _ -> Error("Unsupported image format")
  }
}

fn parse_png_chunks(image, offset) {
  case image {
    <<
      _:unit(8)-size(offset),
      _length:32,
      "IHDR":utf8,
      width:32,
      height:32,
      _rest:bits,
    >> -> Ok(ImageInformation(width, height, "png"))
    <<_:size(offset), length:32, _:4, _:bits>> ->
      parse_png_chunks(image, offset + length + 12)
    _ -> Error("Invalid PNG chunk")
  }
}
