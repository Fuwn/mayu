require "./glyph_image"

module Mayu
  EMBEDDED_THEMES = {{ run("./embedded_themes_generator", __DIR__ + "/../../themes") }}
end
