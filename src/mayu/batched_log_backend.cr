require "log"

module Mayu
  # Writes entries as they are logged but flushes once per batch. The flush runs
  # in a fiber that the scheduler reaches only after the current burst of
  # requests yields, so each burst costs one write instead of one per line.
  class BatchedLogBackend < Log::Backend
    @flush_scheduled = false

    def initialize(@io : IO::FileDescriptor = STDOUT)
      super(:direct)

      @io.flush_on_newline = false
    end

    def write(entry : Log::Entry) : Nil
      Log::ShortFormat.format(entry, @io)
      @io.puts

      return if @flush_scheduled

      @flush_scheduled = true

      spawn do
        @flush_scheduled = false
        @io.flush
      end
    end
  end
end
