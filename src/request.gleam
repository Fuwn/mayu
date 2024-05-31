import database
import gleam/json
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

pub fn handle(request, connection) {
  use _ <- middleware(request)

  case wisp.path_segments(request) {
    ["heart-beat"] ->
      wisp.html_response(string_builder.from_string("alive"), 200)
    ["get", "@" <> name] -> {
      case database.get_counter(connection, name) {
        Ok(counter) -> {
          wisp.ok()
          |> wisp.set_header("Content-Type", "image/svg+xml")
          |> wisp.string_body(svg.xml(
            case wisp.get_query(request) {
              [#("theme", theme)] -> theme
              _ -> "asoul"
            },
            counter.num,
          ))
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
    _ -> wisp.html_response(string_builder.from_string("Not found"), 404)
  }
}
