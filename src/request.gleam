import database
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/string_builder
import svg
import wisp

const default_padding = 6

const max_padding = 12

const max_name_length = 64

fn middleware(request, handle) {
  use <- wisp.log_request(request)
  use <- wisp.rescue_crashes
  use request <- wisp.handle_head(request)

  handle(request)
}

fn require_valid_name(name, continue) {
  case name != "" && string.length(name) <= max_name_length {
    True -> continue()
    False -> wisp.bad_request()
  }
}

fn with_counter(connection, name, respond) {
  use <- require_valid_name(name)

  case database.get_counter(connection, name) {
    Ok(counter) -> respond(counter)
    Error(_) -> wisp.internal_server_error()
  }
}

fn query_theme(query, default_theme) -> String {
  list.key_find(query, "theme") |> result.unwrap(default_theme)
}

fn query_padding(query) -> Int {
  list.key_find(query, "padding")
  |> result.try(int.parse)
  |> result.map(int.clamp(_, min: 0, max: max_padding))
  |> result.unwrap(default_padding)
}

pub fn handle(request, connection, index_html, default_theme) {
  use _ <- middleware(request)

  case wisp.path_segments(request) {
    [] -> wisp.html_response(string_builder.from_string(index_html), 200)
    ["heart-beat"] ->
      wisp.html_response(string_builder.from_string("alive"), 200)
    ["get", "@" <> name] -> {
      use counter <- with_counter(connection, name)

      let query = wisp.get_query(request)

      wisp.ok()
      |> wisp.set_header("Content-Type", "image/svg+xml")
      |> wisp.set_header(
        "Cache-Control",
        "max-age=0, no-cache, no-store, must-revalidate",
      )
      |> wisp.string_builder_body(svg.xml(
        query_theme(query, default_theme),
        default_theme,
        counter.num,
        query_padding(query),
      ))
    }
    ["record", "@" <> name] -> {
      use counter <- with_counter(connection, name)

      wisp.json_response(
        json.to_string_builder(
          json.object([
            #("name", json.string(counter.name)),
            #("num", json.int(counter.num)),
            #("updated_at", json.string(counter.updated_at)),
            #("created_at", json.string(counter.created_at)),
          ]),
        ),
        200,
      )
    }
    _ -> wisp.redirect("https://github.com/Fuwn/mayu")
  }
}
