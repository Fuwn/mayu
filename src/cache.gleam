import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import image
import simplifile
import wisp

pub type CachedImage {
  CachedImage(base64: String, info: image.ImageInformation)
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
      dict.insert(accumulated_themes, theme, load_theme(theme))
    },
  )
}

fn load_theme(theme) -> Dict(Int, CachedImage) {
  let theme_directory = "./themes/" <> theme

  case simplifile.read_directory(theme_directory) {
    Ok(files) ->
      list.fold(files, dict.new(), fn(accumulated_digits, file) {
        case parse_digit_filename(file) {
          Ok(digit) ->
            load_cached_image(theme_directory <> "/" <> file)
            |> result.map(dict.insert(accumulated_digits, digit, _))
            |> result.unwrap(accumulated_digits)
          Error(_) -> accumulated_digits
        }
      })
    Error(_) -> {
      wisp.log_error("Error reading theme directory " <> theme_directory)

      dict.new()
    }
  }
}

fn parse_digit_filename(file) {
  case string.split(file, ".") {
    [digit, _extension] -> int.parse(digit)
    _ -> Error(Nil)
  }
}

fn load_cached_image(path) {
  case simplifile.read_bits(from: path) {
    Ok(image_data) ->
      case image.get_image_information(image_data) {
        Ok(info) ->
          Ok(CachedImage(
            base64: bit_array.base64_encode(image_data, False),
            info: info,
          ))
        Error(_) -> {
          wisp.log_error("Error getting image information for " <> path)

          Error(Nil)
        }
      }
    Error(_) -> {
      wisp.log_error("Error reading image file " <> path)

      Error(Nil)
    }
  }
}

pub fn get_image(cache, theme, digit) -> Option(CachedImage) {
  dict.get(cache, theme)
  |> result.then(fn(theme_images) { dict.get(theme_images, digit) })
  |> option.from_result
}
