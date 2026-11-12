require "./theme_catalog"

module Mayu
  module Homepage
    def self.render(template : String, version : String, themes : ThemeCatalog) : String
      template
        .gsub("{{ VERSION }}", "(v#{version})")
        .gsub("{{ THEME_OPTIONS }}", themes.options_html)
    end
  end
end
