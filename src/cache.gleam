import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import image
import simplifile
import wisp

pub type CachedImage {
  CachedImage(data: BitArray, info: image.ImageInformation)
}

pub type ThemeCache =
  Dict(String, Dict(Int, CachedImage))

pub fn load_themes() {
  list.fold(
    case simplifile.read_directory("./themes") {
      Ok(files) -> files
      Error(_) -> {
        wisp.log_error("Error reading themes directory")

        []
      }
    },
    dict.new(),
    fn(accumulated_themes, theme) {
      dict.insert(
        accumulated_themes,
        theme,
        list.range(0, 9)
          |> list.fold(dict.new(), fn(accumulated_digits, digit) {
            let path =
              "./themes/"
              <> theme
              <> "/"
              <> int.to_string(digit)
              <> "."
              <> case theme {
                "gelbooru-h" | "moebooru-h" | "lain" | "garukura" -> "png"
                _ -> "gif"
              }

            case simplifile.read_bits(from: path) {
              Ok(image_data) -> {
                case image.get_image_information(image_data) {
                  Ok(info) ->
                    dict.insert(
                      accumulated_digits,
                      digit,
                      CachedImage(data: image_data, info: info),
                    )
                  Error(_) -> {
                    wisp.log_error(
                      "Error getting image information for " <> path,
                    )

                    accumulated_digits
                  }
                }
              }
              Error(_) -> {
                wisp.log_error("Error reading image file " <> path)

                accumulated_digits
              }
            }
          }),
      )
    },
  )
}

pub fn get_image(cache, theme, digit) -> Option(CachedImage) {
  dict.get(cache, theme)
  |> result.then(fn(theme_images) { dict.get(theme_images, digit) })
  |> option.from_result
}
