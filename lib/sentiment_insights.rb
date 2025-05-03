require "sentiment_insights/configuration"
require "sentiment_insights/analyzer"
require "sentiment_insights/insights/sentiment"

module SentimentInsights
  class Error < StandardError; end

  def self.configure
    yield(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end
end