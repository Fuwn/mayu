require "log"
require "./mayu/batched_log_backend"
require "./mayu/counter_database"
require "./mayu/inactivity_timeout_tcp_server"
require "./mayu/request_log_handler"
require "./mayu/request_handler"
require "./mayu/theme_catalog"

module Mayu
  VERSION = {{ `shards version "#{__DIR__}/.."`.chomp.stringify }}

  def self.run : Nil
    Log.setup_from_env(backend: BatchedLogBackend.new)

    themes = ThemeCatalog.load
    index_html = File.read("index.html")
      .gsub("{{ VERSION }}", "(v#{VERSION})")
      .gsub("{{ THEME_OPTIONS }}", themes.options_html)
    database = CounterDatabase.open(ENV["MAYU_DATABASE_URL"]?)
    port = ENV["PORT"]?.try(&.to_i?) || 3000

    database.create_or_migrate_table
    start_pruner(database)

    server = HTTP::Server.new([
      RequestLogHandler.new,
      HTTP::ErrorHandler.new,
      RequestHandler.new(database, themes, index_html),
    ])

    # As the container's PID 1, Mayu would otherwise ignore SIGTERM, and
    # `docker stop` would wait for its timeout before killing the process.
    {Signal::TERM, Signal::INT}.each(&.trap { server.close unless server.closed? })
    server.bind(InactivityTimeoutTCPServer.new("::", port))
    Log.info { "Listening on port #{port}" }
    server.listen
  end

  private def self.start_pruner(database) : Nil
    minimum_count = positive_environment_integer("MAYU_PRUNE_MIN_COUNT")
    maximum_age_days = positive_environment_integer("MAYU_PRUNE_AFTER_DAYS")
    interval_hours = positive_environment_integer("MAYU_PRUNE_EVERY_HOURS")

    if minimum_count && maximum_age_days && interval_hours
      spawn do
        loop do
          sleep interval_hours.hours
          database.prune(minimum_count, maximum_age_days)
        rescue error
          Log.error(exception: error) { "Failed to prune stale counters" }
        end
      end
      Log.info { "Counter pruning enabled" }
    elsif ENV.keys.any?(&.starts_with?("MAYU_PRUNE_"))
      Log.warn { "Counter pruning disabled: set all three MAYU_PRUNE_* variables to positive integers" }
    end
  end

  private def self.positive_environment_integer(name) : Int32?
    ENV[name]?.try(&.to_i?(whitespace: false)).try { |value| value if value.positive? }
  end
end

Mayu.run
