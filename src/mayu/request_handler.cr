require "http/server"
require "json"
require "./counter_database"
require "./theme_catalog"

module Mayu
  class RequestHandler
    include HTTP::Handler

    DEFAULT_PADDING         =  6
    MAXIMUM_PADDING         = 12
    MAXIMUM_NAME_LENGTH     = 64
    UNCACHED                = "max-age=0, no-cache, no-store, must-revalidate"
    DEMO_COUNTER            = Counter.new("demo", 1_234_567_890)
    REPOSITORY_URL          = "https://github.com/Fuwn/mayu"
    STREAMED_IMAGE_BYTESIZE = 65_536

    def initialize(@database : CounterDatabase, @themes : ThemeCatalog, @index_html : String)
    end

    def call(context : HTTP::Server::Context) : Nil
      segments = context.request.path.split('/', remove_empty: true)
      route = segments.first?
      counter_name = segments[1]?.try(&.lchop?('@')) if segments.size == 2

      if segments.empty?
        respond(context, "text/html; charset=utf-8", @index_html)
      elsif segments == ["heart-beat"]
        respond(context, "text/plain; charset=utf-8", "alive")
      elsif route == "get" && counter_name
        return unless counter = record_hit_or_reject(context, counter_name)

        query = context.request.query_params
        theme = @themes.theme_or_default(query["theme"]?)
        requested_padding = query["padding"]?.try(&.to_i?(whitespace: false))
        padding = requested_padding.try(&.clamp(0, MAXIMUM_PADDING)) || DEFAULT_PADDING
        rendering = theme.rendering(counter.count, padding)

        # Small images leave in one write. Large ones stream, so they never occupy
        # the heap; a buffered megabyte would grow it for the life of the process.
        if rendering.bytesize > STREAMED_IMAGE_BYTESIZE
          respond(context, "image/svg+xml", rendering)
        else
          respond(context, "image/svg+xml", rendering.to_s)
        end
      elsif route == "record" && counter_name
        return unless counter = record_hit_or_reject(context, counter_name)

        body = {
          name:       counter.name,
          num:        counter.count,
          updated_at: counter.updated_at || "",
          created_at: counter.created_at || "",
        }.to_json

        respond(context, "application/json; charset=utf-8", body)
      else
        context.response.redirect(REPOSITORY_URL, :see_other)
      end
    end

    private def record_hit_or_reject(context, name) : Counter?
      unless context.request.method.in?("GET", "HEAD")
        context.response.headers["Allow"] = "GET, HEAD"

        return respond_empty(context, :method_not_allowed)
      end

      return respond_empty(context, :bad_request) unless valid_name?(name)

      context.response.headers["Cache-Control"] = UNCACHED

      name == "demo" ? DEMO_COUNTER : @database.increment(name)
    end

    private def valid_name?(name)
      !name.empty? && name.grapheme_size <= MAXIMUM_NAME_LENGTH
    end

    private def respond(context, content_type, body : String | Theme::Rendering)
      context.response.content_type = content_type
      context.response.content_length = body.bytesize

      context.response.print(body) unless context.request.method == "HEAD"
    end

    private def respond_empty(context, status : HTTP::Status) : Nil
      context.response.status = status
      context.response.content_length = 0
    end
  end
end
