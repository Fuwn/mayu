require "http/server/handler"
require "log"

module Mayu
  class RequestLogHandler
    include HTTP::Handler

    def call(context : HTTP::Server::Context) : Nil
      call_next(context)
    ensure
      Log.info { "#{context.response.status_code} #{context.request.method} #{context.request.path}" }
    end
  end
end
