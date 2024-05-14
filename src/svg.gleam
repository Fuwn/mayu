import gleam/bit_array
import gleam/int
import gleam/list
import gleam/string_builder
import image
import simplifile

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

fn images(theme, digits, width, height, svgs) {
  case digits {
    [] -> XmlImages(string_builder.to_string(svgs), width, height)
    [digit, ..rest] ->
      case
        simplifile.read_bits(
          from: "./themes/"
          <> theme
          <> "/"
          <> int.to_string(digit)
          <> "."
          <> case theme {
            "gelbooru-h" | "moebooru-h" -> "png"
            _ -> "gif"
          },
        )
      {
        Ok(data) -> {
          case image.get_image_information(data) {
            Ok(information) ->
              images(
                theme,
                rest,
                width + information.width,
                int.max(height, information.height),
                string_builder.append(svgs, image(data, information, width)),
              )
            Error(_) -> XmlImages(string_builder.to_string(svgs), width, height)
          }
        }
        Error(_) -> XmlImages(string_builder.to_string(svgs), width, height)
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
