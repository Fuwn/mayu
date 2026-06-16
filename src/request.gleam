import database
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string_builder
import svg
import wisp

const default_theme = "asoul"

const default_padding = 6

const max_padding = 32

fn middleware(request, handle) {
  let request = wisp.method_override(request)

  use <- wisp.log_request(request)
  use <- wisp.rescue_crashes
  use request <- wisp.handle_head(request)

  handle(request)
}

fn query_theme(query) -> String {
  list.key_find(query, "theme") |> result.unwrap(default_theme)
}

fn query_padding(query) -> Int {
  list.key_find(query, "padding")
  |> result.then(int.parse)
  |> result.map(int.clamp(_, min: 0, max: max_padding))
  |> result.unwrap(default_padding)
}

pub fn handle(request, connection, image_cache, index_html) {
  use _ <- middleware(request)

  case wisp.path_segments(request) {
    [] -> wisp.html_response(string_builder.from_string(index_html), 200)
    ["heart-beat"] ->
      wisp.html_response(string_builder.from_string("alive"), 200)
    ["get", "@" <> name] if name == "" -> wisp.bad_request()
    ["get", "@" <> name] -> {
      case database.get_counter(connection, name) {
        Ok(counter) -> {
          let query = wisp.get_query(request)

          wisp.ok()
          |> wisp.set_header("Content-Type", "image/svg+xml")
          |> wisp.string_builder_body(svg.xml(
            image_cache,
            query_theme(query),
            counter.num,
            query_padding(query),
          ))
        }
        Error(_) -> wisp.unprocessable_entity()
      }
    }
    ["record", "@" <> name] if name == "" -> wisp.bad_request()
    ["record", "@" <> name] -> {
      case database.get_counter(connection, name) {
        Ok(counter) -> {
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
        Error(_) -> wisp.unprocessable_entity()
      }
    }
    _ -> wisp.redirect("https://github.com/Fuwn/mayu")
  }
}
