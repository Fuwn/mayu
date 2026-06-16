import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import image
import simplifile
import wisp

pub type CachedImage {
  CachedImage(base64: String, info: image.ImageInformation)
}

pub type Glyph {
  Digit(Int)
  Start
  End
}

pub type ThemeCache =
  Dict(String, Dict(Glyph, CachedImage))

@external(erlang, "cache_ffi", "store")
pub fn store(cache: ThemeCache) -> Nil

@external(erlang, "cache_ffi", "read")
pub fn read() -> ThemeCache

pub fn load_themes() {
  let themes = case simplifile.read_directory("./themes") {
    Ok(files) -> files
    Error(_) -> {
      wisp.log_error("Error reading themes directory")

      []
    }
  }

  themes
  |> list.map(fn(theme) { #(theme, load_theme(theme)) })
  |> dict.from_list
}

fn load_theme(theme) -> Dict(Glyph, CachedImage) {
  let theme_directory = "./themes/" <> theme
  let files = case simplifile.read_directory(theme_directory) {
    Ok(files) -> files
    Error(_) -> {
      wisp.log_error("Error reading theme directory " <> theme_directory)

      []
    }
  }

  files
  |> list.filter_map(fn(file) {
    use glyph <- result.try(parse_glyph_filename(file))
    use cached_image <- result.try(load_cached_image(
      theme_directory <> "/" <> file,
    ))

    Ok(#(glyph, cached_image))
  })
  |> dict.from_list
}

fn parse_glyph_filename(file) {
  case string.split(file, ".") {
    ["_start", _extension] -> Ok(Start)
    ["_end", _extension] -> Ok(End)
    [digit, _extension] ->
      case int.parse(digit) {
        Ok(parsed_digit) if parsed_digit >= 0 && parsed_digit <= 9 ->
          Ok(Digit(parsed_digit))
        _ -> Error(Nil)
      }
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

pub fn get_image(cache, theme, glyph) -> Result(CachedImage, Nil) {
  dict.get(cache, theme)
  |> result.then(fn(theme_images) { dict.get(theme_images, glyph) })
}

pub fn theme_names(cache) {
  dict.keys(cache)
}
