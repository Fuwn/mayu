require "./glyph_image"

module Mayu
  # Every theme in ./themes, encoded when Mayu is compiled. The encoded images are
  # string literals in the binary's read-only pages, so a theme that is never
  # served is never paged into memory.
  EMBEDDED_THEMES = {{ run("./embedded_themes_generator", __DIR__ + "/../../themes") }}
end
