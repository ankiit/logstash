#!/usr/bin/ruby
#

require "socket"
require "lib/net/message"
require "lib/net/socketmux"
require "lib/net/messages/indexevent"
require "lib/net/messages/ping"
require "set"

$done = false
$lastid = nil
$count = 0
$time = 0
$start = Time.now.to_f

class Client < LogStash::Net::MessageSocketMux
  def gotresponse(msg)
    $count += 1
    $ids.delete(msg.id)

    if $done and $ids.length == 0
      puts "All messages ACK'd (#{$lastid})"
      exit(0)
    end
  end

  def IndexEventResponseHandler(msg)
    gotresponse(msg)
    puts "Response (have #{$count} / want: #{$ids.length} acks); #{msg.inspect}"
  end

  def PingResponseHandler(msg)
    gotresponse(msg)

    now = Time.now.to_f()
    $time += (now - msg.pingdata)
    rate = $count / (now - $start)

    puts "\rK#{$time / $count} (#{rate})"
  end
end

$me = Client.new
$me.connect("localhost", 3001)
$ids = Set.new

def dumplog

  File.open(ARGV[0]).each do |line|
    msg = LogStash::Net::Messages::IndexEventRequest.new
    msg.log_type = "linux-syslog"
    msg.log_data = line[0..-2]
    msg.metadata["source_host"] = "snack.home"
    $me.sendmsg(msg)
    $ids << msg.id

    msg = LogStash::Net::Messages::PingRequest.new
    $me.sendmsg(msg)
    $ids << msg.id

    # slow messages down
    #sleep 1

    # Exponential backoff.
    time = 0.2
    while $ids.length > 200
      puts "Too many messages waiting on ACK, sleeping..."
      sleep time
      time *= 2
      if time > 30
        time = 30
      end
    end
  end

  $me.close()
  $done = true
  #puts "dumper done"
end

y = Thread.new { $me.run }
x = Thread.new { dumplog }
y.join
x.join
