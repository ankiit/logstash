require 'rubygems'
require 'socket'
require 'time'
require 'lib/net/message'
require 'lib/net/messages/indexevent'

# TODO(sissel): Need to implement 'read_until' callbacks.
# read_until(1000, bar) would call 'bar' when our buffer size is 1000 bytes

module Logstash
  MAXMSGLEN = (1 << 20)

  class MessageServer
    def initialize
      @serversock = TCPServer.new(4044)
      @socks = [@serversock]
      @buffers = Hash.new { |h,k| h[k] = "" }
      @count = 0
      @start = Time.now.to_f
    end

    def run
      while true
        s_in, s_out, s_err = IO.select(@socks, nil, @socks, 5)
        if s_in
          s_in.each do |sock|
            handle(sock)
          end
        end
      end
    end

    def handle(sock)
      if sock == @serversock
        server_handle(sock)
      else
        client_handle(sock)
      end
    end

    def server_handle(sock)
      client = sock.accept_nonblock
      @socks << client
      puts "New client: #{client}"
    end
    
    # TODO(sissel): extrapolate the 'read chunks until we get a full message set'
    # code into it's own class.
    def client_handle(sock)
      begin
        have = @buffers[sock].length

        if have < 4
          need = 4
        else
          need = @buffers[sock][0..3].unpack("N")[0] + 4
        end

        if have < need
          @buffers[sock] += sock.read_nonblock(need - have)
        end

        if have >= need
          client_streamready(@buffers[sock][4..need])
          @buffers[sock] = (@buffers[sock][(need + 1)..-1] or "")
        end
      rescue EOFError, IOError
        remove(sock)
      end
    end
      
    def client_streamready(data)
      MessageStream.decode(data) do |msg|
        @count += 1
        #puts msg.inspect
        if @count % 1000 == 0
          duration = Time.now.to_f - @start
          puts "%d finished @ %d/sec => %.1f secs" % [@count, duration, @count  / duration]
        end
      end
    end

    def remove(sock)
      #puts "Removing #{sock}"
      @socks.delete(sock)
      @buffers.delete(sock)
      begin
        #sock.close
      rescue IOError
        # ignore 'close' errors
      end
    end
  end # class MessageServer
end
