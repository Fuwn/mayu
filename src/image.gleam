pub type ImageInformation {
  ImageInformation(width: Int, height: Int, extension: String)
}

pub fn get_image_information(image) {
  case image {
    <<
      0x89,
      "PNG\r\n":utf8,
      0x1A,
      "\n":utf8,
      _length:32,
      "IHDR":utf8,
      width:32,
      height:32,
      _rest:bits,
    >> -> Ok(ImageInformation(width, height, "png"))
    <<
      "GIF":utf8,
      _version:bytes-3,
      width:little-16,
      height:little-16,
      _rest:bits,
    >> -> Ok(ImageInformation(width, height, "gif"))
    _ -> Error("Unsupported image format")
  }
}
