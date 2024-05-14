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

  use connection <- sqlight.with_connection("./data/count.db")

  database.setup(connection)

  let secret_key_base = wisp.random_string(64)
  let assert Ok(_) =
    wisp.mist_handler(
      fn(request) { request.handle(request, connection) },
      secret_key_base,
    )
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}
