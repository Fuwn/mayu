import database
import envoy
import gleam/int
import gleam/json
import gleam/list
import gleam/string
import gleam/string_builder
import svg
import wisp

fn middleware(request, handle) {
  let request = wisp.method_override(request)

  use <- wisp.log_request(request)
  use <- wisp.rescue_crashes
  use request <- wisp.handle_head(request)

  handle(request)
}

pub fn handle(request, connection, image_cache, index_html) {
  use _ <- middleware(request)

  case wisp.path_segments(request) {
    [] ->
      case index_html {
        "" -> wisp.not_found()
        content ->
          wisp.html_response(
            string_builder.from_string(
              string.replace(
                content,
                "{{ MAYU_VERSION }}",
                case envoy.get("MAYU_VERSION") {
                  Ok(version) -> "(v" <> version <> ")"
                  Error(_) -> ""
                },
              ),
            ),
            200,
          )
      }
    ["heart-beat"] ->
      wisp.html_response(string_builder.from_string("alive"), 200)
    ["get", "@" <> name] -> {
      case database.get_counter(connection, name) {
        Ok(counter) -> {
          let query = wisp.get_query(request)

          wisp.ok()
          |> wisp.set_header("Content-Type", "image/svg+xml")
          |> wisp.string_body(
            svg.xml(
              image_cache,
              case list.key_find(query, "theme") {
                Ok(theme) -> theme
                _ -> "asoul"
              },
              counter.num,
              case list.key_find(query, "padding") {
                Ok(padding) ->
                  case int.parse(padding) {
                    Ok(n) -> n
                    Error(_) -> 6
                  }
                _ -> 6
              },
            ),
          )
        }
        Error(_) -> wisp.unprocessable_entity()
      }
    }
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
