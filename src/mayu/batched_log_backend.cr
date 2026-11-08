require "log"

module Mayu
  # `spawn` only enqueues, so the single-threaded scheduler runs the flush after
  # every runnable request fiber blocks or finishes, and the lines logged in that
  # pass leave in one write. A flush can wait on a full pipe, and appending to
  # the buffer meanwhile would lose or repeat lines, so the lock holds writers
  # until it finishes. STDOUT on a terminal is unbuffered and gains nothing.
  class BatchedLogBackend < Log::Backend
    @flush_scheduled = false
    @buffer_lock = Mutex.new

    def initialize(@io : IO::FileDescriptor = STDOUT)
      super(:direct)

      @io.flush_on_newline = false
    end

    def write(entry : Log::Entry) : Nil
      @buffer_lock.synchronize do
        Log::ShortFormat.format(entry, @io)
        @io.puts
      end

      return if @flush_scheduled

      @flush_scheduled = true

      spawn do
        @buffer_lock.synchronize do
          @flush_scheduled = false
          @io.flush
        end
      end
    end
  end
end
