import cache
import gleam/int
import gleam/list
import gleam/string_builder.{type StringBuilder}
import image

type XmlImages {
  XmlImages(xml: StringBuilder, width: Int, height: Int)
}

fn append_image(svgs, base64, image: image.ImageInformation, x_offset) {
  svgs
  |> string_builder.append("<image height=\"")
  |> string_builder.append(int.to_string(image.height))
  |> string_builder.append("\" width=\"")
  |> string_builder.append(int.to_string(image.width))
  |> string_builder.append("\" x=\"")
  |> string_builder.append(int.to_string(x_offset))
  |> string_builder.append("\" y=\"0\" xlink:href=\"data:image/")
  |> string_builder.append(image.extension)
  |> string_builder.append(";base64,")
  |> string_builder.append(base64)
  |> string_builder.append("\"/>")
}

fn images(image_cache, theme, glyphs) -> XmlImages {
  list.fold(
    glyphs,
    XmlImages(string_builder.new(), 0, 0),
    fn(accumulator, glyph) {
      case cache.get_image(image_cache, theme, glyph) {
        Ok(cached_image) ->
          XmlImages(
            append_image(
              accumulator.xml,
              cached_image.base64,
              cached_image.info,
              accumulator.width,
            ),
            accumulator.width + cached_image.info.width,
            int.max(accumulator.height, cached_image.info.height),
          )
        _ -> accumulator
      }
    },
  )
}

fn pad_digits(number, padding) -> List(Int) {
  let assert Ok(digits) = int.digits(int.absolute_value(number), 10)
  let digits_padding = padding - list.length(digits)

  case digits_padding > 0 {
    True -> list.append(list.repeat(0, digits_padding), digits)
    False -> digits
  }
}

fn glyphs(number, padding) {
  let digits = list.map(pad_digits(number, padding), cache.Digit)

  [cache.Start, ..list.append(digits, [cache.End])]
}

pub fn xml(image_cache, theme, number, padding) {
  let rendered_images = images(image_cache, theme, glyphs(number, padding))

  string_builder.new()
  |> string_builder.append(
    "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><svg height=\"",
  )
  |> string_builder.append(int.to_string(rendered_images.height))
  |> string_builder.append(
    "\" style=\"image-rendering: pixelated;\" version=\"1.1\" width=\"",
  )
  |> string_builder.append(int.to_string(rendered_images.width))
  |> string_builder.append(
    "\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"><title>Mayu</title><g>",
  )
  |> string_builder.append_builder(rendered_images.xml)
  |> string_builder.append("</g></svg>")
}
