require "logstash/inputs/base"
require "eventmachine-tail"
require "socket" # for Socket.gethostname

class LogStash::Inputs::File < LogStash::Inputs::Base
  def initialize(url, type, config={}, &block)
    super

    # Hack the hostname into the url.
    # This works since file:// urls don't generally have a host in it.
    @url.host = Socket.gethostname
  end

  def register
    EventMachine::FileGlobWatchTail.new(@url.path, Reader, interval=60,
                                        exclude=[], receiver=self)
  end

  def receive(event)
    event = LogStash::Event.new({
      "@source" => @url.to_s,
      "@message" => event,
      "@type" => @type,
      "@tags" => @tags.clone,
    })
    @logger.debug(["Got event", event])
    @callback.call(event)
  end # def event

  class Reader < EventMachine::FileTail
    def initialize(path, receiver)
      super(path)
      @receiver = receiver
      @buffer = BufferedTokenizer.new  # From eventmachine
    end

    def receive_data(data)
      # TODO(2.0): Support multiline log data
      @buffer.extract(data).each do |line|
        @receiver.receive(line)
      end
    end # def receive_data
  end # class Reader
end # class LogStash::Inputs::File
