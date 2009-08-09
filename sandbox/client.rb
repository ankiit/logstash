#!/usr/bin/ruby
#

require "socket"
require "lib/net/message"
require "lib/net/messages/indexevent"

out = TCPSocket.new("localhost", 4044)

ms = Logstash::MessageStream.new
File.open(ARGV[0]).each do |line|
  ier = Logstash::IndexEventRequest.new
  ier.log_type = "syslog"
  #ier.log_data = line.chomp
  ier.metadata["source_host"] = "snack.home"
  #puts ier.inspect
  ms << ier

  if (ms.message_count > 20)
    data = ms.encode
    encoded = [data.length, data].pack("NA*")
    out.write(encoded)

    ms.clear
  end
end

if (ms.message_count > 0)
  data = ms.encode
  out.write([data.length, data].pack("NA*"))
end
