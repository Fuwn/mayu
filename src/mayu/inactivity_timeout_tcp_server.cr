require "socket"

module Mayu
  class InactivityTimeoutTCPServer < TCPServer
    INACTIVITY_TIMEOUT = 15.seconds

    def accept? : TCPSocket?
      client = super

      if client
        client.read_timeout = INACTIVITY_TIMEOUT
        client.write_timeout = INACTIVITY_TIMEOUT
        client.tcp_nodelay = true
      end

      client
    end
  end
end
