require "socket"

module Mayu
  class InactivityTimeoutTCPServer < TCPServer
    INACTIVITY_TIMEOUT = 15.seconds
    REQUEST_TIMEOUT    = 15.seconds

    def initialize(host : String, port : Int32, @request_timeout : Time::Span = REQUEST_TIMEOUT)
      super(host, port)
    end

    def accept? : TCPSocket?
      return if closed?
      return unless accepted_socket = @fd_lock.read { system_accept }

      handle, blocking = accepted_socket
      client = RequestTimeoutTCPSocket.new(
        handle: handle, family: family, type: type, protocol: protocol, blocking: blocking,
        request_timeout: @request_timeout)
      client.sync = sync?
      client.write_timeout = INACTIVITY_TIMEOUT
      client.tcp_nodelay = true

      client
    end
  end

  # Crystal's `read_timeout` restarts with every read, so a client that trickles
  # its headers a byte at a time could hold the socket indefinitely.
  class RequestTimeoutTCPSocket < TCPSocket
    @request_deadline : Time::Instant

    def initialize(*, handle, family, type, protocol, blocking, @request_timeout : Time::Span)
      super(handle: handle, family: family, type: type, protocol: protocol, blocking: blocking)

      @request_deadline = Time.instant + @request_timeout
    end

    private def unbuffered_read(slice : Bytes) : Int32
      remaining_time = @request_deadline - Time.instant

      raise IO::TimeoutError.new("Request timed out") unless remaining_time.positive?

      self.read_timeout = remaining_time

      super
    end

    private def unbuffered_write(slice : Bytes) : Nil
      super

      @request_deadline = Time.instant + @request_timeout
    end
  end
end
