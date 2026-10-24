import cache
import database
import envoy
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import mist
import pog
import request
import simplifile
import sqlight
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let image_cache = cache.load_themes()

  cache.store(image_cache)

  let default_theme = cache.default_theme(image_cache)
  let assert Ok(index_html_source) = simplifile.read("index.html")
  let index_html =
    index_html_source
    |> string.replace("{{ VERSION }}", "(v" <> version() <> ")")
    |> string.replace(
      "{{ THEME_OPTIONS }}",
      theme_options(image_cache, default_theme),
    )

  use connection <- with_database()

  database.setup(connection)
  start_pruner(connection)

  let port =
    envoy.get("PORT")
    |> result.try(int.parse)
    |> result.unwrap(3000)
  let secret_key_base = wisp.random_string(64)
  let assert Ok(_) =
    wisp_mist.handler(
      fn(incoming_request) {
        request.handle(incoming_request, connection, index_html, default_theme)
      },
      secret_key_base,
    )
    |> mist.new
    |> mist.bind("::")
    |> mist.port(port)
    |> mist.start

  process.sleep_forever()
}

@external(erlang, "mayu_ffi", "version")
fn version() -> String

// A postgres:// URL in MAYU_DATABASE_URL selects Postgres; otherwise the
// counter lives in the local SQLite file.
fn with_database(continue: fn(database.Database) -> a) -> a {
  case envoy.get("MAYU_DATABASE_URL") {
    Ok(url) -> {
      let pool_name = process.new_name("mayu_database")

      case pog.url_config(pool_name, url) {
        Ok(configuration) -> {
          // Under saturation a hit counter should queue briefly rather than
          // shed requests, so the checkout target is generous.
          let configuration =
            configuration
            |> pog.pool_size(25)
            |> pog.queue_target(250)
          let assert Ok(pool) = pog.start(configuration)

          continue(database.Postgres(pool.data))
        }
        Error(_) -> {
          wisp.log_error(
            "Invalid MAYU_DATABASE_URL: expected a postgres:// URL",
          )
          panic as "invalid database url"
        }
      }
    }
    Error(_) -> {
      ensure_data_directory()

      use connection <- sqlight.with_connection("./data/count.db")

      continue(database.Sqlite(connection))
    }
  }
}

fn ensure_data_directory() -> Nil {
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
}

fn start_pruner(connection) -> Nil {
  case prune_configuration() {
    Ok(#(minimum_count, maximum_age_days, interval_hours)) -> {
      let _ =
        process.spawn_unlinked(fn() {
          prune_loop(
            connection,
            minimum_count,
            maximum_age_days,
            interval_hours,
          )
        })

      wisp.log_info("Counter pruning enabled")
    }
    Error(_) ->
      case
        list.any(prune_variable_names, fn(name) {
          result.is_ok(envoy.get(name))
        })
      {
        True ->
          wisp.log_warning(
            "Counter pruning disabled: set all three MAYU_PRUNE_* variables"
            <> " to positive integers",
          )
        False -> Nil
      }
  }
}

fn prune_loop(connection, minimum_count, maximum_age_days, interval_hours) {
  sleep_hours(interval_hours)
  database.prune(connection, minimum_count, maximum_age_days)
  prune_loop(connection, minimum_count, maximum_age_days, interval_hours)
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

const prune_variable_names = [
  "MAYU_PRUNE_MIN_COUNT", "MAYU_PRUNE_AFTER_DAYS", "MAYU_PRUNE_EVERY_HOURS",
]

fn prune_configuration() -> Result(#(Int, Int, Int), Nil) {
  case list.map(prune_variable_names, positive_environment_integer) {
    [Ok(minimum_count), Ok(maximum_age_days), Ok(interval_hours)] ->
      Ok(#(minimum_count, maximum_age_days, interval_hours))
    _ -> Error(Nil)
  }
}

fn positive_environment_integer(name) -> Result(Int, Nil) {
  use value <- result.try(envoy.get(name))
  use parsed_integer <- result.try(int.parse(value))

  case parsed_integer > 0 {
    True -> Ok(parsed_integer)
    False -> Error(Nil)
  }
}

fn theme_options(image_cache, default_theme) {
  image_cache
  |> dict.keys
  |> list.filter(fn(slug) {
    slug == default_theme || !string.ends_with(slug, "-h")
  })
  |> list.sort(string.compare)
  |> list.map(fn(slug) { theme_option(slug, default_theme) })
  |> string.join("\n")
}

fn theme_option(slug, default_theme) {
  "<option value=\""
  <> wisp.escape_html(slug)
  <> "\""
  <> case slug == default_theme {
    True -> " selected"
    False -> ""
  }
  <> ">"
  <> wisp.escape_html(prettify_slug(slug))
  <> "</option>"
}

fn prettify_slug(slug) {
  slug
  |> string.replace("_", "-")
  |> string.split(on: "-")
  |> list.map(string.capitalise)
  |> string.join(" ")
}
