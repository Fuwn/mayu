import cache
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree.{type StringTree}

type XmlImages {
  XmlImages(xml: StringTree, width: Int, height: Int)
}

fn append_image(image_elements, cached_image: cache.CachedImage, x_offset) {
  image_elements
  |> string_tree.append(cached_image.element_prefix)
  |> string_tree.append(int.to_string(x_offset))
  |> string_tree.append(cached_image.element_suffix)
}

fn images(glyph_images, glyphs) -> XmlImages {
  list.fold(glyphs, XmlImages(string_tree.new(), 0, 0), fn(accumulator, glyph) {
    case dict.get(glyph_images, glyph) {
      Ok(cached_image) ->
        XmlImages(
          append_image(accumulator.xml, cached_image, accumulator.width),
          accumulator.width + cached_image.width,
          int.max(accumulator.height, cached_image.height),
        )
      Error(_) -> accumulator
    }
  })
}

fn pad_digits(number, padding) -> List(Int) {
  let digits =
    int.to_string(int.absolute_value(number))
    |> string.to_graphemes
    |> list.filter_map(int.parse)

  list.append(list.repeat(0, padding - list.length(digits)), digits)
}

fn glyphs(number, padding) {
  let digits = list.map(pad_digits(number, padding), cache.Digit)

  [cache.Start, ..list.append(digits, [cache.End])]
}

fn theme_images(
  image_cache,
  theme,
  fallback_theme,
) -> Dict(cache.Glyph, cache.CachedImage) {
  case dict.get(image_cache, theme) {
    Ok(glyph_images) -> glyph_images
    Error(_) ->
      dict.get(image_cache, fallback_theme) |> result.unwrap(dict.new())
  }
}

pub fn xml(theme, fallback_theme, number, padding) {
  let glyph_images = theme_images(cache.read(), theme, fallback_theme)
  let rendered_images = images(glyph_images, glyphs(number, padding))

  string_tree.from_string(
    "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><svg height=\""
    <> int.to_string(rendered_images.height)
    <> "\" style=\"image-rendering: pixelated;\" version=\"1.1\" width=\""
    <> int.to_string(rendered_images.width)
    <> "\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"><title>Mayu</title><g>",
  )
  |> string_tree.append_tree(rendered_images.xml)
  |> string_tree.append("</g></svg>")
}
