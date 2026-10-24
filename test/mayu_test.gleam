import database
import gleam/dict
import gleam/dynamic/decode
import gleam/http
import gleam/http/response
import gleam/json
import gleam/list
import gleam/string
import gleam/string_tree
import gleeunit
import gleeunit/should
import request
import sqlight
import svg
import theme
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

pub fn setup_migrates_legacy_moe_counter_table_test() {
  use connection <- sqlight.with_connection(":memory:")

  let assert Ok(_) =
    sqlight.exec(
      "create table tb_count (
        id integer primary key autoincrement not null unique,
        name text not null unique,
        num int not null default (0)
      ) strict;",
      connection,
    )
  let assert Ok(_) =
    sqlight.exec(
      "insert into tb_count (name, num) values ('legacy', 41);",
      connection,
    )

  database.setup(database.Sqlite(connection))

  let assert Ok(counter) =
    database.increment(database.Sqlite(connection), "legacy")
  let assert Ok(index_counts) =
    sqlight.query(
      "select count(*) from pragma_index_list('tb_count');",
      on: connection,
      with: [],
      expecting: decode.at([0], decode.int),
    )

  counter.count |> should.equal(42)
  counter.created_at |> should.equal("")
  counter.updated_at |> should.not_equal("")
  index_counts |> should.equal([2])
}

pub fn setup_preserves_sqlite_identity_and_name_constraints_test() {
  use connection <- sqlight.with_connection(":memory:")

  database.setup(database.Sqlite(connection))
  database.setup(database.Sqlite(connection))

  let assert Ok(indexed_columns) =
    sqlight.query(
      "select name from pragma_index_info('sqlite_autoindex_tb_count_1');",
      on: connection,
      with: [],
      expecting: decode.at([0], decode.string),
    )
  let assert Ok(_) =
    sqlight.exec(
      "insert into tb_count (id, name) values (128, 'first');",
      connection,
    )
  let assert Error(_) =
    sqlight.exec(
      "insert into tb_count (id, name) values (128, 'duplicate-id');",
      connection,
    )
  let assert Error(_) =
    sqlight.exec("insert into tb_count (name) values ('first');", connection)
  let assert Ok(_) =
    sqlight.exec(
      "delete from tb_count where name = 'first';
       insert into tb_count (name) values ('second');",
      connection,
    )
  let assert Ok(identities) =
    sqlight.query(
      "select id from tb_count where name = 'second';",
      on: connection,
      with: [],
      expecting: decode.at([0], decode.int),
    )

  indexed_columns |> should.equal(["name"])
  identities |> should.equal([129])
  remaining_names(connection) |> should.equal(["second"])
}

pub fn prune_removes_only_idle_low_count_test() {
  use connection <- sqlight.with_connection(":memory:")

  database.setup(database.Sqlite(connection))

  let assert Ok(_) =
    sqlight.exec(
      "insert into tb_count (name, num, created_at, updated_at) values
        ('idle_low', 1, '2000-01-01 00:00:00', '2000-01-01 00:00:00'),
        ('idle_high', 9999, '2000-01-01 00:00:00', '2000-01-01 00:00:00'),
        ('fresh_low', 1, datetime('now'), datetime('now')),
        ('null_timestamp', 1, null, null);",
      connection,
    )

  database.prune(database.Sqlite(connection), 10, 30)

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
      expecting: decode.at([0], decode.string),
    )

  names
}

fn theme_cache(theme_name, glyphs) {
  dict.from_list([
    #(
      theme_name,
      glyphs
        |> list.map(fn(glyph) {
          #(
            glyph,
            theme.CachedImage(
              element_prefix: "<image data-glyph=\""
                <> string.inspect(glyph)
                <> "\" x=\"",
              element_suffix: "\"/>",
              width: 10,
              height: 20,
            ),
          )
        })
        |> dict.from_list,
    ),
  ])
}

const digit_glyphs = [
  theme.Digit(0),
  theme.Digit(1),
  theme.Digit(2),
  theme.Digit(3),
  theme.Digit(4),
  theme.Digit(5),
  theme.Digit(6),
  theme.Digit(7),
  theme.Digit(8),
  theme.Digit(9),
]

pub fn xml_falls_back_to_the_default_theme_test() {
  theme.store_cache(theme_cache("known", digit_glyphs))

  let rendered_image =
    svg.xml("does-not-exist", "known", 7, 3) |> string_tree.to_string

  rendered_image |> string.contains("width=\"30\"") |> should.be_true
  rendered_image |> string.contains("height=\"20\"") |> should.be_true
}

pub fn xml_renders_nothing_for_a_theme_missing_from_every_cache_test() {
  theme.store_cache(theme_cache("known", digit_glyphs))

  svg.xml("does-not-exist", "also-missing", 7, 3)
  |> string_tree.to_string
  |> string.contains("<image")
  |> should.be_false
}

pub fn default_theme_prefers_a_loaded_theme_over_the_preferred_name_test() {
  theme_cache("gelbooru-h", digit_glyphs)
  |> theme.default_name
  |> should.equal("gelbooru-h")
}

pub fn request_counts_hits_and_preserves_encoded_names_test() {
  use connection <- sqlight.with_connection(":memory:")

  database.setup(database.Sqlite(connection))
  theme.store_cache(theme_cache("known", digit_glyphs))

  let image_response =
    request.handle(
      simulate.request(http.Get, "/get/@has%20space?padding=999"),
      database.Sqlite(connection),
      "index",
      "known",
    )
  let record_response =
    request.handle(
      simulate.request(http.Get, "/record/@has%20space"),
      database.Sqlite(connection),
      "index",
      "known",
    )

  image_response.status |> should.equal(200)
  response.get_header(image_response, "Cache-Control")
  |> should.equal(Ok("max-age=0, no-cache, no-store, must-revalidate"))
  simulate.read_body(image_response)
  |> string.contains("width=\"120\"")
  |> should.be_true
  simulate.read_body(record_response)
  |> json.parse(decode.at(["num"], decode.int))
  |> should.equal(Ok(2))
  remaining_names(connection) |> should.equal(["has%20space"])
}

pub fn request_rejects_invalid_names_without_creating_rows_test() {
  use connection <- sqlight.with_connection(":memory:")

  database.setup(database.Sqlite(connection))

  list.each(["", string.repeat("a", 65)], fn(name) {
    let record_response =
      request.handle(
        simulate.request(http.Get, "/record/@" <> name),
        database.Sqlite(connection),
        "index",
        "known",
      )

    record_response.status |> should.equal(400)
  })

  remaining_names(connection) |> should.equal([])
}

pub fn demo_never_creates_a_database_row_test() {
  use connection <- sqlight.with_connection(":memory:")

  database.setup(database.Sqlite(connection))
  request.handle(
    simulate.request(http.Get, "/record/@demo"),
    database.Sqlite(connection),
    "index",
    "known",
  )
  |> simulate.read_body
  |> json.parse(decode.at(["num"], decode.int))
  |> should.equal(Ok(1_234_567_890))
  remaining_names(connection) |> should.equal([])
}

pub fn xml_preserves_glyph_order_padding_and_bookends_test() {
  theme.store_cache(
    theme_cache("known", [theme.Start, theme.End, ..digit_glyphs]),
  )

  let rendered_image = svg.xml("known", "known", 12, 3) |> string_tree.to_string

  rendered_image
  |> string.contains(
    "<image data-glyph=\"Start\" x=\"0\"/><image data-glyph=\"Digit(0)\" x=\"10\"/><image data-glyph=\"Digit(1)\" x=\"20\"/><image data-glyph=\"Digit(2)\" x=\"30\"/><image data-glyph=\"End\" x=\"40\"/>",
  )
  |> should.be_true
}
