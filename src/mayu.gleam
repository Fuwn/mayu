import cache
import database
import envoy
import gleam/erlang/process
import gleam/list
import gleam/string
import mist
import request
import simplifile
import sqlight
import wisp

pub fn main() {
  wisp.configure_logger()

  case simplifile.create_directory("./data") {
    Ok(_) | Error(simplifile.Eexist) -> Nil
    Error(error) -> {
      wisp.log_error(
        "Failed to create ./data directory: "
        <> simplifile.describe_error(error),
      )
      panic as "cannot create data directory"
    }
  }
  let image_cache = cache.load_themes()
  let version_tag = case envoy.get("MAYU_VERSION") {
    Ok(version) -> "(v" <> version <> ")"
    Error(_) -> ""
  }
  let assert Ok(index_html_source) = simplifile.read("index.html")
  let index_html =
    index_html_source
    |> string.replace("{{ MAYU_VERSION }}", version_tag)
    |> string.replace("{{ THEME_OPTIONS }}", theme_options(image_cache))

  use connection <- sqlight.with_connection("./data/count.db")

  database.setup(connection)

  let secret_key_base = wisp.random_string(64)
  let assert Ok(_) =
    wisp.mist_handler(
      fn(incoming_request) {
        request.handle(incoming_request, connection, image_cache, index_html)
      },
      secret_key_base,
    )
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}

const default_theme = "asoul"

fn theme_options(image_cache) {
  image_cache
  |> cache.theme_names
  |> list.filter(fn(slug) { !string.ends_with(slug, "-h") })
  |> list.sort(string.compare)
  |> list.map(theme_option)
  |> string.join("\n")
}

fn theme_option(slug) {
  let selected = case slug == default_theme {
    True -> " selected"
    False -> ""
  }

  "<option value=\""
  <> slug
  <> "\""
  <> selected
  <> ">"
  <> prettify_slug(slug)
  <> "</option>"
}

fn prettify_slug(slug) {
  slug
  |> string.replace("_", "-")
  |> string.split(on: "-")
  |> list.map(capitalize)
  |> string.join(" ")
}

fn capitalize(word) {
  case string.pop_grapheme(word) {
    Ok(#(first, rest)) -> string.uppercase(first) <> rest
    Error(_) -> word
  }
}
