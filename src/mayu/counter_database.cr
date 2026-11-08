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
    def initialize(@connection : DB::Database | DB::Connection, @increment_statement : String,
                   @prune_statement : String)
    end

    def self.open(url : String?) : CounterDatabase
      url ? PostgresCounterDatabase.open(url) : SqliteCounterDatabase.open
    end

    abstract def create_or_migrate_table : Nil

    def increment(name : String) : Counter
      @connection.query_one(@increment_statement, name, as: Counter)
    end

    def prune(minimum_count : Int32, maximum_age_days : Int32) : Nil
      @connection.exec(@prune_statement, minimum_count, maximum_age_days)
    end
  end
end

require "./postgres_counter_database"
require "./sqlite_counter_database"
