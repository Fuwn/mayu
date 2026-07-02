import cache
import database
import envoy
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/result
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

  cache.store(image_cache)

  let default_theme = cache.default_theme(image_cache)
  let version_tag = case envoy.get("MAYU_VERSION") {
    Ok(version) -> "(v" <> version <> ")"
    Error(_) -> ""
  }
  let assert Ok(index_html_source) = simplifile.read("index.html")
  let index_html =
    index_html_source
    |> string.replace("{{ MAYU_VERSION }}", version_tag)
    |> string.replace("{{ DEFAULT_THEME }}", default_theme)
    |> string.replace(
      "{{ THEME_OPTIONS }}",
      theme_options(image_cache, default_theme),
    )

  use connection <- sqlight.with_connection("./data/count.db")

  database.setup(connection)
  start_pruner(connection)

  let secret_key_base = wisp.random_string(64)
  let assert Ok(_) =
    wisp.mist_handler(
      fn(incoming_request) {
        request.handle(incoming_request, connection, index_html, default_theme)
      },
      secret_key_base,
    )
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}

fn start_pruner(connection) -> Nil {
  case prune_config() {
    Ok(#(min_count, max_age_days, interval_hours)) -> {
      let _ =
        process.start(
          fn() {
            prune_loop(connection, min_count, max_age_days, interval_hours)
          },
          False,
        )

      wisp.log_info("Counter pruning enabled")
    }
    Error(_) -> Nil
  }
}

fn prune_loop(connection, min_count, max_age_days, interval_hours) {
  sleep_hours(interval_hours)
  database.prune(connection, min_count, max_age_days)
  prune_loop(connection, min_count, max_age_days, interval_hours)
}

const milliseconds_per_hour = 3_600_000

// Erlang caps receive timeouts at about 49 days, and a longer sleep crashes
// the process. Sleeping one hour at a time keeps any interval valid.
fn sleep_hours(hours) -> Nil {
  case hours > 0 {
    True -> {
      process.sleep(milliseconds_per_hour)
      sleep_hours(hours - 1)
    }
    False -> Nil
  }
}

fn prune_config() -> Result(#(Int, Int, Int), Nil) {
  use min_count <- result.try(positive_env_int("MAYU_PRUNE_MIN_COUNT"))
  use max_age_days <- result.try(positive_env_int("MAYU_PRUNE_AFTER_DAYS"))
  use interval_hours <- result.try(positive_env_int("MAYU_PRUNE_EVERY_HOURS"))

  Ok(#(min_count, max_age_days, interval_hours))
}

fn positive_env_int(name) -> Result(Int, Nil) {
  use value <- result.try(envoy.get(name))
  use parsed <- result.try(int.parse(value))

  case parsed > 0 {
    True -> Ok(parsed)
    False -> Error(Nil)
  }
}

fn theme_options(image_cache, default_theme) {
  image_cache
  |> cache.theme_names
  |> list.filter(fn(slug) { !string.ends_with(slug, "-h") })
  |> list.sort(string.compare)
  |> list.map(fn(slug) { theme_option(slug, default_theme) })
  |> string.join("\n")
}

fn theme_option(slug, default_theme) {
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
