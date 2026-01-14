import cache
import database
import gleam/erlang/process
import mist
import request
import simplifile
import sqlight
import wisp

pub fn main() {
  wisp.configure_logger()

  let _ = simplifile.create_directory("./data")
  let image_cache = cache.load_themes()
  let index_html = case simplifile.read("index.html") {
    Ok(content) -> content
    Error(_) -> {
      wisp.log_error("Failed to read index.html")

      ""
    }
  }

  use connection <- sqlight.with_connection("./data/count.db")

  database.setup(connection)

  let secret_key_base = wisp.random_string(64)
  let assert Ok(_) =
    wisp.mist_handler(
      fn(request) {
        request.handle(request, connection, image_cache, index_html)
      },
      secret_key_base,
    )
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}
