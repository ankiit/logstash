require 'rubygems'
require 'mqrpc'

module MQRPC::Messages
  class PingRequest < MQRPC::RequestMessage
    def initialize
      super
      self.pingdata = Time.now.to_f
    end

    hashbind :pingdata, "/args/pingdata"
  end # class PingRequest < RequestMessage

  class PingResponse < MQRPC::ResponseMessage
    hashbind :pingdata, "/args/pingdata"
  end
end