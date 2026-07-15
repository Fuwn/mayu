import envoy
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
  let enabled_themes =
    envoy.get("MAYU_THEMES")
    |> result.unwrap("")
    |> string.split(",")
    |> list.map(string.trim)
    |> list.filter(fn(name) { name != "" })

  let themes = read_directory_or_empty("./themes")

  let selected_themes = case enabled_themes {
    [] -> themes
    _ -> list.filter(themes, fn(theme) { list.contains(enabled_themes, theme) })
  }

  selected_themes
  |> list.map(fn(theme) { #(theme, load_theme(theme)) })
  |> dict.from_list
}

fn read_directory_or_empty(path) -> List(String) {
  case simplifile.read_directory(path) {
    Ok(files) -> files
    Error(_) -> {
      wisp.log_error("Error reading directory " <> path)

      []
    }
  }
}

fn load_theme(theme) -> Dict(Glyph, CachedImage) {
  let theme_directory = "./themes/" <> theme
  let files = read_directory_or_empty(theme_directory)
  let glyphs =
    files
    |> list.filter_map(fn(file) {
      use glyph <- result.try(parse_glyph_filename(file))
      use cached_image <- result.try(load_cached_image(
        theme_directory <> "/" <> file,
      ))

      Ok(#(glyph, cached_image))
    })
    |> dict.from_list

  warn_if_incomplete(theme, glyphs)

  glyphs
}

fn warn_if_incomplete(theme, glyphs) -> Nil {
  let missing =
    list.range(0, 9)
    |> list.filter(fn(digit) { !dict.has_key(glyphs, Digit(digit)) })

  case missing {
    [] -> Nil
    _ ->
      wisp.log_warning(
        "Theme "
        <> theme
        <> " is missing digit glyphs: "
        <> { missing |> list.map(int.to_string) |> string.join(", ") },
      )
  }
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
  use image_data <- result.try(
    simplifile.read_bits(from: path)
    |> result.map_error(fn(_) {
      wisp.log_error("Error reading image file " <> path)
    }),
  )
  use info <- result.map(
    image.get_image_information(image_data)
    |> result.map_error(fn(_) {
      wisp.log_error("Error getting image information for " <> path)
    }),
  )

  CachedImage(base64: bit_array.base64_encode(image_data, True), info: info)
}

pub fn get_image(cache, theme, glyph) -> Result(CachedImage, Nil) {
  dict.get(cache, theme)
  |> result.try(fn(theme_images) { dict.get(theme_images, glyph) })
}

const preferred_default_theme = "asoul"

pub fn default_theme(cache) -> String {
  let names =
    cache
    |> dict.keys
    |> list.sort(string.compare)

  case list.contains(names, preferred_default_theme) {
    True -> preferred_default_theme
    False ->
      names
      |> list.filter(fn(name) { !string.ends_with(name, "-h") })
      |> list.first
      |> result.unwrap(preferred_default_theme)
  }
}
