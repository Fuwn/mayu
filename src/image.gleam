import gleam/int

pub type ImageDimensions {
  ImageDimensions(width: Int, height: Int)
}

pub fn get_image_dimensions(image) {
  case image {
    <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _:bits>> ->
      parse_png_chunks(image, 8)
    <<
      0x47,
      0x49,
      0x46,
      _:16,
      _:unsigned,
      width_0:8,
      width_1:8,
      height_0:8,
      height_1:8,
      _rest:bits,
    >> ->
      Ok(ImageDimensions(
        width_0
          |> int.bitwise_or(
          width_1
          |> int.bitwise_shift_left(8),
        ),
        height_0
          |> int.bitwise_or(
          height_1
          |> int.bitwise_shift_left(8),
        ),
      ))
    _ -> Error("Invalid PNG signature")
  }
}

fn parse_png_chunks(image, offset) {
  let offset_bits = offset * 8

  case image {
    <<
      _:size(offset_bits),
      _length:32,
      "IHDR":utf8,
      width:32,
      height:32,
      _:bits,
    >> -> Ok(ImageDimensions(width, height))
    <<_:size(offset), length:32, _:4, _:bits>> ->
      parse_png_chunks(image, offset + length + 12)
    _ -> Error("Invalid PNG chunk")
  }
}
