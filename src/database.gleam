import birl
import gleam/dynamic
import sqlight

pub type Counter {
  Counter(name: String, num: Int, created_at: String, updated_at: String)
}

pub fn setup(connection) {
  let assert Ok(_) =
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
    let _ =
      sqlight.exec(
        "update tb_count set " <> name <> " = current_timestamp;",
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

pub fn get_counter(connection, name) {
  let assert Ok(_) =
    sqlight.query(
      "insert or ignore into tb_count (name) values (?);",
      with: [sqlight.text(name)],
      on: connection,
      expecting: dynamic.optional(dynamic.int),
    )
  let assert Ok(_) =
    sqlight.query(
      "update tb_count set num = num + 1, updated_at = ? where name = ?;",
      with: [sqlight.text(birl.to_iso8601(birl.utc_now())), sqlight.text(name)],
      on: connection,
      expecting: dynamic.int,
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
