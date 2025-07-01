import birl
import gleam/dynamic
import gleam/option
import gleam/string
import sqlight
import wisp

pub type Counter {
  Counter(name: String, num: Int, created_at: String, updated_at: String)
}

pub fn setup(connection) {
  let _ =
    sqlight.exec(
      "pragma foreign_keys = off;

      create table if not exists tb_count (
        id integer primary key autoincrement not null unique,
        name text not null unique,
        num int not null default (0)
      ) strict;",
      connection,
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

fn sqlite_now() {
  birl.to_iso8601(birl.utc_now())
  |> string.slice(0, 19)
  |> string.replace("T", " ")
}

pub fn get_counter(connection, name) {
  case name {
    "demo" -> Ok(Counter("demo", 1_234_567_890, "", ""))
    _ -> {
      case
        sqlight.query(
          "INSERT INTO tb_count (name, created_at, updated_at, num)
          VALUES (?1, ?2, ?2, 1)
          ON CONFLICT(name) DO UPDATE SET
            num = tb_count.num + 1,
            updated_at = excluded.updated_at
          RETURNING name, num, created_at, updated_at;",
          with: [sqlight.text(name), sqlight.text(sqlite_now())],
          on: connection,
          expecting: dynamic.tuple4(
            dynamic.string,
            dynamic.int,
            dynamic.optional(dynamic.string),
            dynamic.optional(dynamic.string),
          ),
        )
      {
        Ok([row]) ->
          Ok(Counter(
            row.0,
            row.1,
            option.unwrap(row.2, ""),
            option.unwrap(row.3, ""),
          ))
        Ok([]) -> {
          wisp.log_error("Database query returned no rows unexpectedly.")

          Error("Unreachable entity")
        }
        Ok([_, _, ..]) -> {
          wisp.log_error("Database query returned multiple rows unexpectedly.")

          Error("Unreachable entity")
        }
        Error(_) -> {
          wisp.log_error("Database query failed.")

          Error("Database operation failed")
        }
      }
    }
  }
}
