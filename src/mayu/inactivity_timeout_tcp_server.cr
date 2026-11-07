require "socket"

module Mayu
  class InactivityTimeoutTCPServer < TCPServer
    INACTIVITY_TIMEOUT = 15.seconds

    def accept? : TCPSocket?
      client = super

      if client
        client.read_timeout = INACTIVITY_TIMEOUT
        client.write_timeout = INACTIVITY_TIMEOUT
      end

      client
    end
  end
end
