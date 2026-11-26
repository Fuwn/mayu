require "file_utils"
require "log/spec"
require "spec"
require "../src/mayu/batched_log_backend"
require "../src/mayu/counter_database"
require "../src/mayu/embedded_themes"
require "../src/mayu/homepage"
require "../src/mayu/request_handler"
require "../src/mayu/request_log_handler"
require "../src/mayu/request_timeout_tcp_server"
require "../src/mayu/theme_catalog"

SQLITE_DATETIME_PATTERN = /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/

def with_sqlite(*, create_table = true, & : DB::Connection, Mayu::CounterDatabase ->)
  DB.connect("sqlite3://%3Amemory%3A") do |connection|
    database = Mayu::SqliteCounterDatabase.new(connection)

    database.create_or_migrate_table if create_table

    yield connection, database
  end
end

def with_accepted_socket(request_timeout = Mayu::RequestTimeoutTCPServer::REQUEST_TIMEOUT, & : TCPSocket, TCPSocket ->)
  server = Mayu::RequestTimeoutTCPServer.new("127.0.0.1", 0, request_timeout)
  client = TCPSocket.new("127.0.0.1", server.local_address.port)
  accepted_socket = server.accept?.not_nil!

  yield client, accepted_socket
ensure
  accepted_socket.try(&.close)
  client.try(&.close)
  server.try(&.close)
end

def gunzip(compressed_data : Bytes | String) : String
  Compress::Gzip::Reader.open(IO::Memory.new(compressed_data), &.gets_to_end)
end

def remaining_names(connection) : Array(String)
  connection.query_all("select name from tb_count order by name;", as: String)
end

def stub_theme(theme_name, glyph_names) : Mayu::Theme
  glyph_images = glyph_names.to_h do |glyph_name|
    {glyph_name, Mayu::GlyphImage.new(id: glyph_name, definition: %(<image id="#{glyph_name}"/>), width: 10, height: 20)}
  end

  Mayu::Theme.new(theme_name, glyph_images)
end

def large_theme(theme_name) : Mayu::Theme
  glyph_images = Mayu::Theme::GLYPH_NAMES.to_h do |glyph_name|
    definition = %(<image id="#{glyph_name}" data="#{glyph_name * 9000}"/>)

    {glyph_name, Mayu::GlyphImage.new(id: glyph_name, definition: definition, width: 10, height: 20)}
  end

  Mayu::Theme.new(theme_name, glyph_images)
end

def handle_request(database, method, resource, headers = HTTP::Headers.new,
                   themes = Mayu::ThemeCatalog.new([stub_theme("known", Mayu::Theme::DIGIT_NAMES), large_theme("large")])) : HTTP::Client::Response
  output = IO::Memory.new
  request = HTTP::Request.new(method, resource, headers)
  response = HTTP::Server::Response.new(output)
  handler = Mayu::RequestHandler.new(database, themes, "index")

  handler.call(HTTP::Server::Context.new(request, response))
  response.close
  output.rewind

  HTTP::Client::Response.from_io(output, ignore_body: method == "HEAD", decompress: false)
end
