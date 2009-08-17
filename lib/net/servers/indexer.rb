
require 'rubygems'
require 'lib/net/server'
require 'lib/net/message'
require 'lib/net/messages/indexevent'
require 'lib/net/messages/search'
require 'lib/net/messages/ping'

require 'ferret'
require 'lib/log/text'
require 'config'


module LogStash; module Net; module Servers
  class Indexer < LogStash::Net::MessageServer
    SYNCDELAY = 60

    def initialize(addr="0.0.0.0", port=3001)
      # 'super' is not the same as 'super()', and we want super().
      super()
      listen(addr, port)
      @indexes = Hash.new
      @lines = Hash.new { |h,k| h[k] = 0 }
    end

    def IndexEventRequestHandler(request)
      response = LogStash::Net::Messages::IndexEventResponse.new
      response.id = request.id
      puts request.inspect

      log_type = request.log_type
      entry = $logs[log_type].parse_entry(request.log_data)
      if !entry
        response.code = 1
        response.error = "Entry was #{entry.inspect} (log parsing failed)"
      else
        response.code = 0
        if not @indexes.member?(log_type)
          @indexes[log_type] = $logs[log_type].get_index
        end

        entry["@LOG_TYPE"] = log_type
        @indexes[log_type] << entry
      end
      yield response
    end

    def PingRequestHandler(request)
      response = LogStash::Net::Messages::PingResponse.new
      response.id = request.id
      response.pingdata = request.pingdata
      yield response
    end

    def SearchRequestHandler(request)
      puts "Search for #{request.query.inspect}"

      reader = Ferret::Index::IndexReader.new($logs[request.log_type].index_dir)
      search = Ferret::Search::Searcher.new(reader)

      puts reader.fields.join("\n")
      qp = Ferret::QueryParser.new(:fields => reader.fields,
                                   :tokenized_fields => reader.tokenized_fields,
                                   :or_default => false)
      query = qp.parse(request.query)
      search.search_each(query, :limit => :all, 
                         :sort => "@DATE") do |docid, score|
        result =  reader[docid][:@LINE]
        response = LogStash::Net::Messages::SearchResponse.new
        response.id = request.id
        response.results = [result]
        yield response
      end
      response = LogStash::Net::Messages::SearchResponse.new
      response.id = request.id
      response.results = []
      response.finished = true
      yield response
    end

    # Special 'run' override because we want sync to disk once per minute.
    def run
      synctime = Time.now + SYNCDELAY
      sleeptime = 1
      loop do
        active = sendrecv(sleeptime)
        if !active
          sleeptime *= 2
          if sleeptime > SYNCDELAY
            sleeptime = SYNCDELAY
          end
          puts "No activity, sleeping for #{sleeptime}"
        end

        if Time.now > synctime
          @indexes.each do |log_type,index|
            puts "Time's up. Syncing #{log_type}"
            index.commit
          end

          synctime = Time.now + 60
        end
      end
    end # def run

  end # Indexer
end; end; end # LogStash::Net::Server
