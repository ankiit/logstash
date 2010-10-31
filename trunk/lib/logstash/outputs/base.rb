require "logstash/namespace"
require "logstash/event"
require "uri"

class LogStash::Outputs::Base
  def initialize(url, config={}, &block)
    @url = url
    @url = URI.parse(url) if url.is_a? String
    @config = config
  end

  def register
    throw "#{self.class}#register must be overidden"
  end # def register

  def receive(event)
    throw "#{self.class}#receive must be overidden"
  end
end # class LogStash::Outputs::Base
