require "http/server/handler"
require "log"

module Mayu
  class RequestLogHandler
    include HTTP::Handler

    MAXIMUM_LOGGED_PATH_SIZE = 256

    def call(context : HTTP::Server::Context) : Nil
      call_next(context)
    ensure
      Log.info do
        path = context.request.path
        logged_path = path.size > MAXIMUM_LOGGED_PATH_SIZE ? "#{path[0, MAXIMUM_LOGGED_PATH_SIZE]}…" : path

        "#{context.response.status_code} #{context.request.method} #{logged_path}"
      end
    end
  end
end
