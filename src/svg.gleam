import gleam/bit_array
import gleam/int
import gleam/list
import gleam/string_builder
import image
import simplifile

type XmlImages {
  XmlImages(xml: String, width: Int, height: Int)
}

fn image(data, dimensions: image.ImageDimensions, width, extension) {
  "<image
    height=\"" <> int.to_string(dimensions.height) <> "\"
    width=\"" <> int.to_string(dimensions.width) <> "\"
    x=\"" <> int.to_string(width) <> "\"
    y=\"0\"
    xlink:href=\"data:image/" <> extension <> ";base64," <> bit_array.base64_encode(
    data,
    False,
  ) <> "\"/>"
}

fn images(theme, digits, width, height, svgs) {
  case digits {
    [] -> XmlImages(string_builder.to_string(svgs), width, height)
    [digit, ..rest] -> {
      let extension = case theme {
        "asoul" | "gelbooru" | "moebooru" | "rule34" | "urushi" -> "gif"
        _ -> "png"
      }

      case
        simplifile.read_bits(
          from: "./themes/"
          <> theme
          <> "/"
          <> int.to_string(digit)
          <> "."
          <> extension,
        )
      {
        Ok(data) -> {
          case image.get_image_dimensions(data) {
            Ok(dimensions) ->
              images(
                theme,
                rest,
                width + dimensions.width,
                int.max(height, dimensions.height),
                string_builder.append(
                  svgs,
                  image(data, dimensions, width, extension),
                ),
              )
            Error(_) -> XmlImages(string_builder.to_string(svgs), width, height)
          }
        }
        Error(_) -> XmlImages(string_builder.to_string(svgs), width, height)
      }
    }
  }
}

pub fn xml(theme, number) {
  let xml =
    images(
      theme,
      {
        let assert Ok(digits) = int.digits(number, 10)
        let digits_padding = 6 - list.length(digits)

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
