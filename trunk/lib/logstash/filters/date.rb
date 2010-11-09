require "logstash/filters/base"
require "logstash/time"

class LogStash::Filters::Date < LogStash::Filters::Base
  # The 'date' filter will take a value from your event and use it as the
  # event timestamp. This is useful for parsing logs generated on remote
  # servers or for importing old logs.
  #
  # The config looks like this:
  #
  # filters:
  #   date:
  #     <type>:
  #       <fieldname>: <format>
  #     <type>
  #       <fieldname>: <format>
  #
  # The format is whatever is supported by Ruby's DateTime.strptime
  def initialize(config = {})
    super

    @types = Hash.new { |h,k| h[k] = [] }
  end # def initialize

  def register
    @config.each do |type, typeconfig|
      @logger.debug "Setting type #{type.inspect} to the config #{typeconfig.inspect}"
      raise "date filter type \"#{type}\" defined more than once" unless @types[type].empty?
      @types[type] = typeconfig
    end # @config.each
  end # def register

  def filter(event)
    @logger.debug "DATE FILTER: received event of type #{event.type}"
    return unless @types.member?(event.type)
    @types[event.type].each do |field, format|
      @logger.debug "DATE FILTER: type #{event.type}, looking for field #{field.inspect} with format #{format.inspect}"
      # TODO(sissel): check event.message, too.
      if event.fields.member?(field)
        fieldvalue = event.fields[field]
        fieldvalue = [fieldvalue] if fieldvalue.is_a?(String)
        fieldvalue.each do |value|
          if format == "ISO8601"
            event.timestamp = value
          else
            begin
              time = DateTime.strptime(value, format)
              event.timestamp = LogStash::Time.to_iso8601(time)
              @logger.debug "Parsed #{value.inspect} as #{event.timestamp}"
            rescue
              @logger.warn "Failed parsing date #{value.inspect} from field #{field} with format #{format.inspect}: #{$!}"
            end
          end
        end # fieldvalue.each 
      end # if this event has a field we expect to be a timestamp
    end # @types[event.type].each
  end # def filter
end # class LogStash::Filters::Date
