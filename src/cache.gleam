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
  CachedImage(
    element_prefix: String,
    element_suffix: String,
    width: Int,
    height: Int,
  )
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
  let image_cache =
    selected_themes
    |> list.filter_map(fn(theme) {
      let glyphs = load_theme(theme)

      case dict.is_empty(glyphs), missing_digits(glyphs) {
        True, _ -> {
          wisp.log_error("Ignoring " <> theme <> ": no glyphs found")

          Error(Nil)
        }
        False, [] -> Ok(#(theme, glyphs))
        False, missing_digit_numbers -> {
          wisp.log_warning(
            "Theme "
            <> theme
            <> " is missing digit glyphs: "
            <> {
              missing_digit_numbers
              |> list.map(int.to_string)
              |> string.join(", ")
            },
          )

          Ok(#(theme, glyphs))
        }
      }
    })
    |> dict.from_list

  case dict.is_empty(image_cache) {
    True ->
      wisp.log_error(
        "No themes loaded: check ./themes and MAYU_THEMES; counters will still be recorded",
      )
    False -> Nil
  }

  image_cache
}

fn read_directory_or_empty(path) -> List(String) {
  case simplifile.read_directory(path) {
    Ok(files) -> files
    Error(error) -> {
      wisp.log_error(
        "Failed to read theme directory "
        <> path
        <> ": "
        <> simplifile.describe_error(error),
      )

      []
    }
  }
}

fn load_theme(theme) -> Dict(Glyph, CachedImage) {
  let theme_directory = "./themes/" <> theme

  theme_directory
  |> read_directory_or_empty
  |> list.filter_map(fn(file) {
    use glyph <- result.try(parse_glyph_filename(file))
    use cached_image <- result.try(load_cached_image(
      theme_directory <> "/" <> file,
    ))

    Ok(#(glyph, cached_image))
  })
  |> dict.from_list
}

fn missing_digits(glyphs) -> List(Int) {
  int.range(from: 0, to: 10, with: [], run: fn(missing_digit_numbers, digit) {
    case dict.has_key(glyphs, Digit(digit)) {
      True -> missing_digit_numbers
      False -> [digit, ..missing_digit_numbers]
    }
  })
  |> list.reverse
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
    |> result.map_error(fn(error) {
      wisp.log_error(
        "Failed to read image "
        <> path
        <> ": "
        <> simplifile.describe_error(error),
      )
    }),
  )
  use image_information <- result.map(
    image.get_image_information(image_data)
    |> result.map_error(fn(error) {
      wisp.log_error("Failed to load image " <> path <> ": " <> error)
    }),
  )

  cached_image(image_data, image_information)
}

fn cached_image(
  image_data,
  image_information: image.ImageInformation,
) -> CachedImage {
  CachedImage(
    element_prefix: "<image height=\""
      <> int.to_string(image_information.height)
      <> "\" width=\""
      <> int.to_string(image_information.width)
      <> "\" x=\"",
    element_suffix: "\" y=\"0\" xlink:href=\"data:image/"
      <> image_information.extension
      <> ";base64,"
      <> bit_array.base64_encode(image_data, True)
      <> "\"/>",
    width: image_information.width,
    height: image_information.height,
  )
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
      |> result.or(list.first(names))
      |> result.unwrap(preferred_default_theme)
  }
}
