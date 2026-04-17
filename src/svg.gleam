import cache
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string_builder.{type StringBuilder}
import image

type XmlImages {
  XmlImages(xml: StringBuilder, width: Int, height: Int)
}

fn append_image(svgs, base64, image: image.ImageInformation, width) {
  svgs
  |> string_builder.append("<image height=\"")
  |> string_builder.append(int.to_string(image.height))
  |> string_builder.append("\" width=\"")
  |> string_builder.append(int.to_string(image.width))
  |> string_builder.append("\" x=\"")
  |> string_builder.append(int.to_string(width))
  |> string_builder.append("\" y=\"0\" xlink:href=\"data:image/")
  |> string_builder.append(image.extension)
  |> string_builder.append(";base64,")
  |> string_builder.append(base64)
  |> string_builder.append("\"/>")
}

fn images(image_cache, theme, digits, width, height, svgs) {
  case digits {
    [] -> XmlImages(svgs, width, height)
    [digit, ..rest] ->
      case cache.get_image(image_cache, theme, digit) {
        Some(cached) ->
          images(
            image_cache,
            theme,
            rest,
            width + cached.info.width,
            int.max(height, cached.info.height),
            append_image(svgs, cached.base64, cached.info, width),
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

  string_builder.new()
  |> string_builder.append(
    "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><svg height=\"",
  )
  |> string_builder.append(int.to_string(xml.height))
  |> string_builder.append(
    "\" style=\"image-rendering: pixelated;\" version=\"1.1\" width=\"",
  )
  |> string_builder.append(int.to_string(xml.width))
  |> string_builder.append(
    "\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"><title>Mayu</title><g>",
  )
  |> string_builder.append_builder(xml.xml)
  |> string_builder.append("</g></svg>")
  |> string_builder.to_string()
}
