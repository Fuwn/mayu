require "log"
require "./mayu/batched_log_backend"
require "./mayu/counter_database"
require "./mayu/embedded_themes"
require "./mayu/inactivity_timeout_tcp_server"
require "./mayu/request_log_handler"
require "./mayu/request_handler"
require "./mayu/theme_catalog"

module Mayu
  VERSION = {{ `shards version "#{__DIR__}/.."`.chomp.stringify }}

  def self.run : Nil
    Log.setup_from_env(backend: BatchedLogBackend.new)

    themes = ThemeCatalog.load(EMBEDDED_THEMES)
    index_html = File.read("index.html")
      .gsub("{{ VERSION }}", "(v#{VERSION})")
      .gsub("{{ THEME_OPTIONS }}", themes.options_html)
    database = CounterDatabase.open(ENV["MAYU_DATABASE_URL"]?)
    port = ENV["PORT"]?.try(&.to_i?) || 3000

    database.create_or_migrate_table

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
end

Mayu.run
