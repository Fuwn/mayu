import database
import gleam/dynamic
import gleam/list
import gleeunit
import gleeunit/should
import sqlight

pub fn main() {
  gleeunit.main()
}

pub fn prune_removes_only_idle_low_count_test() {
  use connection <- sqlight.with_connection(":memory:")

  database.setup(connection)

  let assert Ok(_) =
    sqlight.exec(
      "insert into tb_count (name, num, created_at, updated_at) values
        ('idle_low', 1, '2000-01-01 00:00:00', '2000-01-01 00:00:00'),
        ('idle_high', 9999, '2000-01-01 00:00:00', '2000-01-01 00:00:00'),
        ('fresh_low', 1, datetime('now'), datetime('now')),
        ('null_timestamp', 1, null, null);",
      connection,
    )

  database.prune(connection, 10, 30)

  let remaining = remaining_names(connection)

  remaining |> list.contains("idle_low") |> should.be_false
  remaining |> list.contains("idle_high") |> should.be_true
  remaining |> list.contains("fresh_low") |> should.be_true
  remaining |> list.contains("null_timestamp") |> should.be_true
}

fn remaining_names(connection) -> List(String) {
  let assert Ok(names) =
    sqlight.query(
      "select name from tb_count order by name;",
      on: connection,
      with: [],
      expecting: dynamic.element(0, dynamic.string),
    )

  names
}
