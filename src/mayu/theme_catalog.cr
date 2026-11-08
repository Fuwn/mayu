require "html"
require "log"
require "./theme"

module Mayu
  class ThemeCatalog
    PREFERRED_DEFAULT_NAME = "asoul"

    getter default_name : String
    @themes_by_name : Hash(String, Theme)

    def initialize(themes : Enumerable(Theme))
      @themes_by_name = themes.to_h { |theme| {theme.name, theme} }
      @default_name = PREFERRED_DEFAULT_NAME

      unless @themes_by_name.has_key?(PREFERRED_DEFAULT_NAME)
        sorted_themes = @themes_by_name.values.sort_by!(&.name)
        fallback_theme = sorted_themes.find { |theme| !theme.adult? } || sorted_themes.first?

        @default_name = fallback_theme.name if fallback_theme
      end
    end

    def self.load(glyph_images_by_theme_name : Hash(String, Hash(String, GlyphImage)),
                  enabled_names : String? = ENV["MAYU_THEMES"]?) : ThemeCatalog
      enabled_theme_names = (enabled_names || "").split(',').map(&.strip).reject(&.empty?)
      selected_glyph_images = glyph_images_by_theme_name.select do |theme_name|
        enabled_theme_names.empty? || enabled_theme_names.includes?(theme_name)
      end
      catalog = new(selected_glyph_images.compact_map { |theme_name, glyph_images| Theme.validated(theme_name, glyph_images) })

      if catalog.empty?
        Log.error { "No themes loaded: check the themes Mayu was built with and MAYU_THEMES; counters will still be recorded" }
      end

      catalog
    end

    def empty? : Bool
      @themes_by_name.empty?
    end

    def theme_or_default(name : String?) : Theme
      name.try { |theme_name| @themes_by_name[theme_name]? } ||
        @themes_by_name[@default_name]? ||
        Theme.new(@default_name, {} of String => GlyphImage)
    end

    def options_html : String
      @themes_by_name.values
        .select { |theme| theme.name == @default_name || !theme.adult? }
        .sort_by!(&.name)
        .join('\n') do |theme|
          selected = theme.name == @default_name ? " selected" : ""
          label = HTML.escape(prettify(theme.name))

          %(<option value="#{HTML.escape(theme.name)}"#{selected}>#{label}</option>)
        end
    end

    private def prettify(name)
      name.tr("_", "-").split('-').join(' ', &.capitalize)
    end
  end
end
