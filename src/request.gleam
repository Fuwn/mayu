import database
import gleam/json
import gleam/string_builder
import svg
import wisp.{type Response}

fn middleware(
  request: wisp.Request,
  handle: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let request = wisp.method_override(request)

  use <- wisp.log_request(request)
  use <- wisp.rescue_crashes
  use request <- wisp.handle_head(request)

  handle(request)
}

pub fn handle(request, connection) -> Response {
  use _ <- middleware(request)

  case wisp.path_segments(request) {
    ["heart-beat"] ->
      wisp.html_response(string_builder.from_string("alive"), 200)
    ["get", "@" <> name] ->
      wisp.ok()
      |> wisp.set_header("Content-Type", "image/svg+xml")
      |> wisp.string_body(svg.xml(
        case wisp.get_query(request) {
          [#("theme", theme)] -> theme
          _ -> "asoul"
        },
        database.get_counter(connection, name).num,
      ))
    ["record", "@" <> name] -> {
      let counter = database.get_counter(connection, name)

      case
        Ok(
          json.to_string_builder(
            json.object([
              #("name", json.string(counter.name)),
              #("num", json.int(counter.num)),
              #("updated_at", json.string(counter.updated_at)),
              #("created_at", json.string(counter.created_at)),
            ]),
          ),
        )
      {
        Ok(builder) -> wisp.json_response(builder, 200)
        Error(_) -> wisp.unprocessable_entity()
      }
    }
    _ -> wisp.html_response(string_builder.from_string("Not found"), 404)
  }
}
