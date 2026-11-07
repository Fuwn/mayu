require "sqlite3"
require "./counter_database"

module Mayu
  class SqliteCounterDatabase < CounterDatabase
    URL = "sqlite3://./data/count.db?journal_mode=wal&synchronous=normal&busy_timeout=5000"

    INCREMENT_STATEMENT = <<-SQL
      insert into tb_count (name, created_at, updated_at, num)
      values (?, datetime('now'), datetime('now'), 1)
      on conflict (name) do update set
        num = tb_count.num + 1,
        updated_at = datetime('now')
      returning name, num, created_at, updated_at;
      SQL

    PRUNE_STATEMENT = <<-SQL
      delete from tb_count
      where num < ?1
        and updated_at is not null
        and updated_at < datetime('now', '-' || ?2 || ' days');
      SQL

    def self.open : SqliteCounterDatabase
      Dir.mkdir_p("./data")

      new(DB.open(URL))
    end

    def create_or_migrate_table : Nil
      @connection.exec <<-SQL
        create table if not exists tb_count (
          id integer primary key autoincrement not null,
          name text not null unique,
          num int not null default (0)
        ) strict;
        SQL

      existing_column_names = @connection.query_all(
        "select name from pragma_table_info('tb_count');", as: String)

      {"created_at", "updated_at"}.each do |column_name|
        unless existing_column_names.includes?(column_name)
          @connection.exec "alter table tb_count add column #{column_name} text;"
        end
      end
    end

    private def increment_statement : String
      INCREMENT_STATEMENT
    end

    private def prune_statement : String
      PRUNE_STATEMENT
    end
  end
end
