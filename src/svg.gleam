import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree.{type StringTree}
import theme

type RenderedGlyphs {
  RenderedGlyphs(
    definitions: StringTree,
    references: StringTree,
    defined_images: List(String),
    width: Int,
    height: Int,
  )
}

fn add_glyph(rendered: RenderedGlyphs, cached_image: theme.CachedImage) {
  let is_defined =
    list.contains(rendered.defined_images, cached_image.reference_prefix)
  let references =
    rendered.references
    |> string_tree.append(cached_image.reference_prefix)
    |> string_tree.append(int.to_string(rendered.width))
    |> string_tree.append("\"/>")

  case is_defined {
    True -> RenderedGlyphs(..rendered, references:)
    False ->
      RenderedGlyphs(
        ..rendered,
        definitions: string_tree.append(
          rendered.definitions,
          cached_image.definition,
        ),
        references:,
        defined_images: [
          cached_image.reference_prefix,
          ..rendered.defined_images
        ],
      )
  }
}

fn render_glyphs(glyph_images, glyphs) -> RenderedGlyphs {
  let empty = RenderedGlyphs(string_tree.new(), string_tree.new(), [], 0, 0)

  list.fold(glyphs, empty, fn(rendered, glyph) {
    case dict.get(glyph_images, glyph) {
      Ok(cached_image) -> {
        let rendered = add_glyph(rendered, cached_image)

        RenderedGlyphs(
          ..rendered,
          width: rendered.width + cached_image.width,
          height: int.max(rendered.height, cached_image.height),
        )
      }
      Error(_) -> rendered
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
    <> "\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"><title>Mayu</title><defs>",
  )
  |> string_tree.append_tree(rendered_glyphs.definitions)
  |> string_tree.append("</defs><g>")
  |> string_tree.append_tree(rendered_glyphs.references)
  |> string_tree.append("</g></svg>")
}
