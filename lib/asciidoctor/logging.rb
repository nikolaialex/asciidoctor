require 'logger'

module Asciidoctor
class Logger < ::Logger
  def initialize *args
    super
    self.progname = 'asciidoctor'
    self.formatter = BasicFormatter.new
    self.level = WARN
  end

  class BasicFormatter < Formatter
    SEVERITY_LABELS = { 'WARN' => 'WARNING', 'FATAL' => 'FAILED' }

    def call severity, _, progname, msg
      %(#{progname}: #{SEVERITY_LABELS[severity] || severity}: #{::String === msg ? msg : msg.inspect}\n)
    end
  end

  module AutoFormattingMessage
    def inspect
      (sloc = self[:source_location]) ? %(#{sloc}: #{self[:text]}) : self[:text]
    end
  end
end

class MemoryLogger < ::Logger
  # NOTE Ruby 1.8.7 returns constants as strings instead of symbols
  SEVERITY_LABELS = ::Hash[Severity.constants.map {|c| [(Severity.const_get c), c.to_sym] }]

  attr_reader :messages

  def initialize
    self.level = WARN
    @messages = []
  end

  def add severity, message = nil, progname = nil
    message = block_given? ? yield : progname unless message
    @messages << { :severity => SEVERITY_LABELS[severity], :message => message }
    true
  end
end

class NullLogger < ::Logger
  def initialize; end

  def add *args
    true
  end
end

module LoggerManager
  @logger_class = Logger
  class << self
    attr_accessor :logger_class

    # NOTE subsequent calls to logger access the logger via the logger property directly
    def logger pipe = $stderr
      memoize_logger
      @logger ||= (@logger_class.new pipe)
    end

    def logger= logger
      @logger = logger || (@logger_class.new $stderr)
    end

    private
    def memoize_logger
      class << self
        alias_method :logger, :logger
        if RUBY_ENGINE == 'opal'
          define_method :logger do @logger end
        else
          attr_reader :logger
        end
      end
    end
  end
end

module Logging
  def self.included into
    into.extend Logging
  end

  private
  def logger
    LoggerManager.logger
  end

  def enrich_message text, context = {}
    ({ :text => text }.merge context).extend Logger::AutoFormattingMessage
  end
end
end
