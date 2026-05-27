import gleam/dynamic
import gleam/list
import gleam/option
import sqlight
import wisp

pub type Counter {
  Counter(name: String, num: Int, created_at: String, updated_at: String)
}

pub fn setup(connection) {
  let assert Ok(_) =
    sqlight.exec(
      "create table if not exists tb_count (
        id integer primary key autoincrement not null unique,
        name text not null unique,
        num int not null default (0)
      ) strict;",
      connection,
    )
  let existing_column_names = existing_columns(connection)
  let ensure_column = fn(name) {
    case list.contains(existing_column_names, name) {
      True -> Nil
      False -> {
        let assert Ok(_) =
          sqlight.exec(
            "alter table tb_count add column " <> name <> " text;",
            connection,
          )

        Nil
      }
    }
  }

  ensure_column("created_at")
  ensure_column("updated_at")

  Nil
}

fn existing_columns(connection) -> List(String) {
  let assert Ok(columns) =
    sqlight.query(
      "pragma table_info('tb_count');",
      with: [],
      on: connection,
      expecting: dynamic.element(1, dynamic.string),
    )

  columns
}

pub fn get_counter(connection, name) {
  case name {
    "demo" -> Ok(Counter("demo", 1_234_567_890, "", ""))
    _ -> {
      case
        sqlight.query(
          "INSERT INTO tb_count (name, created_at, updated_at, num)
           VALUES (?1, datetime('now'), datetime('now'), 1)
           ON CONFLICT(name) DO UPDATE SET
             num = tb_count.num + 1,
             updated_at = datetime('now')
           RETURNING name, num, created_at, updated_at;",
          with: [sqlight.text(name)],
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
        _ -> {
          wisp.log_error("Database query failed or returned unexpected rows.")

          Error("Database operation failed")
        }
      }
    }
  }
}
