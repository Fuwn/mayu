require "./spec_helper"

describe Mayu::CounterDatabase do
  it "migrates a legacy Moe-Counter table" do
    with_sqlite do |connection, database|
      connection.exec <<-SQL
        create table tb_count (
          id integer primary key autoincrement not null unique,
          name text not null unique,
          num int not null default (0)
        ) strict;
        SQL
      connection.exec "insert into tb_count (name, num) values ('legacy', 41);"
      database.create_or_migrate_table

      counter = database.increment("legacy")
      index_count = connection.scalar("select count(*) from pragma_index_list('tb_count');")

      counter.count.should eq(42)
      counter.created_at.should be_nil
      counter.updated_at.should_not be_nil
      index_count.should eq(2)
    end
  end

  it "preserves SQLite identity and name constraints" do
    with_sqlite do |connection, database|
      database.create_or_migrate_table
      database.create_or_migrate_table

      indexed_columns = connection.query_all(
        "select name from pragma_index_info('sqlite_autoindex_tb_count_1');", as: String)

      connection.exec "insert into tb_count (id, name) values (128, 'first');"
      expect_raises(SQLite3::Exception) do
        connection.exec "insert into tb_count (id, name) values (128, 'duplicate-id');"
      end
      expect_raises(SQLite3::Exception) do
        connection.exec "insert into tb_count (name) values ('first');"
      end
      connection.exec "delete from tb_count where name = 'first';"
      connection.exec "insert into tb_count (name) values ('second');"

      identities = connection.query_all("select id from tb_count where name = 'second';", as: Int64)

      indexed_columns.should eq(["name"])
      identities.should eq([129])
      remaining_names(connection).should eq(["second"])
    end
  end

  it "prunes only idle, low-count counters" do
    with_sqlite do |connection, database|
      database.create_or_migrate_table
      connection.exec <<-SQL
        insert into tb_count (name, num, created_at, updated_at) values
          ('idle_low', 1, '2000-01-01 00:00:00', '2000-01-01 00:00:00'),
          ('idle_high', 9999, '2000-01-01 00:00:00', '2000-01-01 00:00:00'),
          ('fresh_low', 1, datetime('now'), datetime('now')),
          ('null_timestamp', 1, null, null);
        SQL
      database.prune(10, 30)
      remaining_names(connection).should eq(["fresh_low", "idle_high", "null_timestamp"])
    end
  end
end

describe Mayu::Theme do
  it "preserves glyph order, padding, and bookends" do
    rendered_image = theme("known", ["_start", "_end"] + DIGIT_GLYPHS).rendering(12, 3).to_s

    rendered_image.should contain(
      %(<g><use xlink:href="#_start" x="0"/><use xlink:href="#0" x="10"/>) \
      %(<use xlink:href="#1" x="20"/><use xlink:href="#2" x="30"/><use xlink:href="#_end" x="40"/></g>))
  end

  it "defines each repeated glyph once" do
    rendered_image = theme("known", ["_start", "_end"] + DIGIT_GLYPHS).rendering(1100, 0).to_s

    rendered_image.should contain(
      %(<defs><image id="_start"/><image id="1"/><image id="0"/><image id="_end"/></defs>))
    rendered_image.scan("<use ").size.should eq(6)
  end

  it "defines identical images once even under different glyph names" do
    shared_image = Mayu::GlyphImage.new(id: "shared", definition: %(<image id="shared"/>), width: 10, height: 20)
    glyph_images = {"_start" => shared_image, "_end" => shared_image, "1" => shared_image}
    rendered_image = Mayu::Theme.new("bookends", glyph_images).rendering(1, 1).to_s

    rendered_image.scan(%(<image id="shared"/>)).size.should eq(1)
    rendered_image.scan("<use ").size.should eq(3)
  end

  it "declares the exact size of every rendering" do
    themed = theme("known", ["_start", "_end"] + DIGIT_GLYPHS)

    {0_i64, 7_i64, 1100_i64, 1_234_567_890_i64, Int64::MAX}.each do |number|
      {0, 6, 12}.each do |padding|
        rendering = themed.rendering(number, padding)

        rendering.bytesize.should eq(rendering.to_s.bytesize)
      end
    end
  end
end

describe Mayu::ThemeCatalog do
  it "falls back to the default theme" do
    themes = Mayu::ThemeCatalog.new([theme("known", DIGIT_GLYPHS)])
    rendered_image = themes.theme_or_default("does-not-exist").rendering(7, 3).to_s

    rendered_image.should contain(%(width="30"))
    rendered_image.should contain(%(height="20"))
  end

  it "renders nothing when no theme is loaded" do
    themes = Mayu::ThemeCatalog.new([] of Mayu::Theme)
    rendered_image = themes.theme_or_default("does-not-exist").rendering(7, 3).to_s

    rendered_image.should_not contain("<image")
  end

  it "prefers a loaded theme over the preferred name" do
    Mayu::ThemeCatalog.new([theme("gelbooru-h", DIGIT_GLYPHS)]).default_name.should eq("gelbooru-h")
  end
end

describe Mayu::RequestHandler do
  it "counts hits and preserves encoded names" do
    with_sqlite do |connection, database|
      database.create_or_migrate_table

      image_response = handle_request(database, "GET", "/get/@has%20space?padding=999")
      record_response = handle_request(database, "GET", "/record/@has%20space")

      image_response.status_code.should eq(200)
      image_response.headers["Cache-Control"].should eq("max-age=0, no-cache, no-store, must-revalidate")
      image_response.body.should contain(%(width="120"))
      record_response.headers["Cache-Control"].should eq("max-age=0, no-cache, no-store, must-revalidate")
      JSON.parse(record_response.body)["num"].should eq(2)
      remaining_names(connection).should eq(["has%20space"])
    end
  end

  it "rejects invalid names without creating rows" do
    with_sqlite do |connection, database|
      database.create_or_migrate_table
      ["", "a" * 65].each do |name|
        handle_request(database, "GET", "/record/@#{name}").status_code.should eq(400)
      end
      remaining_names(connection).should be_empty
    end
  end

  it "counts HEAD and rejects other methods" do
    with_sqlite do |connection, database|
      database.create_or_migrate_table

      rejected_statuses = ["POST", "PUT", "DELETE"].map do |method|
        handle_request(database, method, "/record/@methods").status_code
      end
      head_response = handle_request(database, "HEAD", "/record/@counted")

      rejected_statuses.should eq([405, 405, 405])
      head_response.status_code.should eq(200)
      remaining_names(connection).should eq(["counted"])
    end
  end

  it "never creates a database row for demo" do
    with_sqlite do |connection, database|
      database.create_or_migrate_table

      record_response = handle_request(database, "GET", "/record/@demo")

      JSON.parse(record_response.body)["num"].should eq(1_234_567_890)
      remaining_names(connection).should be_empty
    end
  end
end
