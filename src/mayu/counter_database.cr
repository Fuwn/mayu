require "db"

module Mayu
  struct Counter
    include DB::Serializable

    getter name : String
    @[DB::Field(key: "num")]
    getter count : Int64
    getter created_at : String?
    getter updated_at : String?

    def initialize(@name, @count, @created_at = nil, @updated_at = nil)
    end
  end

  abstract class CounterDatabase
    def initialize(@connection : DB::Database | DB::Connection, @increment_statement : String)
    end

    # An empty URL counts as unset, because deployment tools often define the
    # variable without a value.
    def self.open(url : String?) : CounterDatabase
      if postgres_url = url.presence
        PostgresCounterDatabase.open(postgres_url)
      else
        SqliteCounterDatabase.open
      end
    end

    abstract def create_or_migrate_table : Nil

    def increment(name : String) : Counter
      @connection.query_one(@increment_statement, name, as: Counter)
    end
  end
end

require "./postgres_counter_database"
require "./sqlite_counter_database"
