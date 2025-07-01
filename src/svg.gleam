import cache
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string_builder
import image

type XmlImages {
  XmlImages(xml: String, width: Int, height: Int)
}

fn image(data, image: image.ImageInformation, width) {
  "<image
    height=\"" <> int.to_string(image.height) <> "\"
    width=\"" <> int.to_string(image.width) <> "\"
    x=\"" <> int.to_string(width) <> "\"
    y=\"0\"
    xlink:href=\"data:image/" <> image.extension <> ";base64," <> bit_array.base64_encode(
    data,
    False,
  ) <> "\"/>"
}

fn images(image_cache, theme, digits, width, height, svgs) {
  case digits {
    [] -> XmlImages(string_builder.to_string(svgs), width, height)
    [digit, ..rest] ->
      case cache.get_image(image_cache, theme, digit) {
        Some(cached) ->
          images(
            image_cache,
            theme,
            rest,
            width + cached.info.width,
            int.max(height, cached.info.height),
            string_builder.append(svgs, image(cached.data, cached.info, width)),
          )
        _ -> images(image_cache, theme, rest, width, height, svgs)
      }
  }
}

pub fn xml(image_cache, theme, number, padding) {
  let xml =
    images(
      image_cache,
      theme,
      {
        let assert Ok(digits) = int.digits(number, 10)
        let digits_padding = padding - list.length(digits)

        case digits_padding {
          n if n > 0 -> list.concat([list.repeat(0, digits_padding), digits])
          _ -> digits
        }
      },
      0,
      0,
      string_builder.new(),
    )

  "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>
  <svg
    height=\"" <> int.to_string(xml.height) <> "\"
    style=\"image-rendering: pixelated;\"
    version=\"1.1\"
    width=\"" <> int.to_string(xml.width) <> "\"
    xmlns=\"http://www.w3.org/2000/svg\"
    xmlns:xlink=\"http://www.w3.org/1999/xlink\"
  >
    <title>Mayu</title>

    <g>" <> xml.xml <> "</g>
  </svg>"
}
