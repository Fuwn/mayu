import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree.{type StringTree}
import theme

type RenderedGlyphs {
  RenderedGlyphs(elements: StringTree, width: Int, height: Int)
}

fn append_image(image_elements, cached_image: theme.CachedImage, x_offset) {
  image_elements
  |> string_tree.append(cached_image.element_prefix)
  |> string_tree.append(int.to_string(x_offset))
  |> string_tree.append(cached_image.element_suffix)
}

fn render_glyphs(glyph_images, glyphs) -> RenderedGlyphs {
  list.fold(
    glyphs,
    RenderedGlyphs(string_tree.new(), 0, 0),
    fn(accumulator, glyph) {
      case dict.get(glyph_images, glyph) {
        Ok(cached_image) ->
          RenderedGlyphs(
            append_image(accumulator.elements, cached_image, accumulator.width),
            accumulator.width + cached_image.width,
            int.max(accumulator.height, cached_image.height),
          )
        Error(_) -> accumulator
      }
    },
  )
}

fn pad_digits(number, padding) -> List(Int) {
  let digits =
    int.to_string(int.absolute_value(number))
    |> string.to_graphemes
    |> list.filter_map(int.parse)

  list.append(list.repeat(0, padding - list.length(digits)), digits)
}

fn glyphs(number, padding) {
  let digits = list.map(pad_digits(number, padding), theme.Digit)

  [theme.Start, ..list.append(digits, [theme.End])]
}

fn theme_images(
  image_cache,
  theme_name,
  fallback_theme_name,
) -> Dict(theme.Glyph, theme.CachedImage) {
  case dict.get(image_cache, theme_name) {
    Ok(glyph_images) -> glyph_images
    Error(_) ->
      dict.get(image_cache, fallback_theme_name) |> result.unwrap(dict.new())
  }
}

pub fn xml(theme_name, fallback_theme_name, number, padding) {
  let glyph_images =
    theme_images(theme.read_cache(), theme_name, fallback_theme_name)
  let rendered_glyphs = render_glyphs(glyph_images, glyphs(number, padding))

  string_tree.from_string(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><svg height=\""
    <> int.to_string(rendered_glyphs.height)
    <> "\" style=\"image-rendering: pixelated;\" version=\"1.1\" width=\""
    <> int.to_string(rendered_glyphs.width)
    <> "\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"><title>Mayu</title><g>",
  )
  |> string_tree.append_tree(rendered_glyphs.elements)
  |> string_tree.append("</g></svg>")
}
