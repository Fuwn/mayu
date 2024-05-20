import birl
import gleam/dynamic
import gleam/io
import gleam/string
import sqlight

pub type Counter {
  Counter(name: String, num: Int, created_at: String, updated_at: String)
}

fn check_error(result, message) {
  case result {
    Ok(_) -> Nil
    Error(_) -> {
      io.print(message)

      Nil
    }
  }
}

pub fn setup(connection) {
  check_error(
    sqlight.exec(
      "pragma foreign_keys = off;

      create table if not exists tb_count (
        id integer primary key autoincrement not null unique,
        name text not null unique,
        num int not null default (0)
      ) strict;",
      connection,
    ),
    "Failed to create table tb_count",
  )

  let add_column = fn(name) {
    let _ =
      sqlight.exec(
        "alter table tb_count add column " <> name <> " text;",
        connection,
      )

    Nil
  }

  add_column("created_at")
  add_column("updated_at")

  Nil
}

pub fn add_counter(connection, name) {
  sqlight.query(
    "insert into tb_count (name) values (?);",
    with: [sqlight.text(name)],
    on: connection,
    expecting: dynamic.optional(dynamic.int),
  )
}

fn sqlite_now() {
  birl.to_iso8601(birl.utc_now())
  |> string.slice(0, 19)
  |> string.replace("T", " ")
}

pub fn get_counter(connection, name) {
  case name {
    "demo" -> Counter("demo", 0_123_456_789, "", "")
    _ -> {
      check_error(
        sqlight.query(
          "insert or ignore into tb_count (name, created_at) values (?, ?);",
          with: [sqlight.text(name), sqlight.text(sqlite_now())],
          on: connection,
          expecting: dynamic.optional(dynamic.int),
        ),
        "Failed to insert or ignore into tb_count",
      )
      check_error(
        sqlight.query(
          "update tb_count set num = num + 1, updated_at = ? where name = ?;",
          with: [sqlight.text(sqlite_now()), sqlight.text(name)],
          on: connection,
          expecting: dynamic.int,
        ),
        "Failed to update tb_count",
      )

      case
        sqlight.query(
          "select name, num, created_at, updated_at from tb_count where name = ?;",
          with: [sqlight.text(name)],
          on: connection,
          expecting: dynamic.tuple4(
            dynamic.string,
            dynamic.int,
            dynamic.string,
            dynamic.string,
          ),
        )
      {
        Ok([first_element]) -> {
          Counter(
            first_element.0,
            first_element.1,
            first_element.2,
            first_element.3,
          )
        }
        _ -> Counter(name, 0, "", "")
      }
    }
  }
}
