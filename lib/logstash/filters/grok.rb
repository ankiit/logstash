require "logstash/filters/base"

gem "jls-grok", ">=0.2.3071"
require "grok" # rubygem 'jls-grok'

class LogStash::Filters::Grok < LogStash::Filters::Base
  def initialize(config = {})
    super

    @grokpiles = {}
  end # def initialize

  def register
    # TODO(sissel): Make patterns files come from the config
    @config.each do |tag, tagconfig|
      @logger.debug("Registering tag with grok: #{tag}")
      pile = Grok::Pile.new
      pile.add_patterns_from_file("patterns/grok-patterns")
      pile.add_patterns_from_file("patterns/linux-syslog")
      tagconfig["patterns"].each do |pattern|
        pile.compile(pattern)
      end
      @grokpiles[tag] = pile
    end # @config.each
  end # def register

  def filter(event)
    # parse it with grok
    message = event.message
    match = false

    if !event.tags.empty?
      event.tags.each do |tag|
        if @grokpiles.include?(tag)
          pile = @grokpiles[tag]
          grok, match = pile.match(message)
          break if match
        end # @grokpiles.include?(tag)
      end # event.tags.each
    else 
      # TODO(2.0): support grok pattern discovery
      #pattern = @grok.discover(message)
      #@grok.compile(pattern)
      #match = @grok.match(message)
      @logger.info("No known tag for #{event.source} (tags: #{event.tags.inspect})")
      @logger.debug(event.to_hash)
    end

    if match
      match.each_capture do |key, value|
        if key.include?(":")
          key = key.split(":")[1]
        end
        if event.message == value
          # Skip patterns that match the entire line
          @logger.debug("Skipping capture '#{key}' since it matches the whole line.")
          next
        end

        if event.fields[key].is_a?(String)
          event.fields[key] = [event.fields[key]]
        elsif event.fields[key] == nil
          event.fields[key] = []
        end

        event.fields[key] << value
      end
    else
      # Tag this event if we can't parse it. We can use this later to
      # reparse+reindex logs if we improve the patterns given .
      event.tags << "_grokparsefailure"
    end
  end # def filter
end # class LogStash::Filters::Grok
