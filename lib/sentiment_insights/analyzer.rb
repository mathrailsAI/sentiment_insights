require "sentiment_insights/clients/sentiment/open_ai_client"
require "sentiment_insights/clients/sentiment/aws_comprehend_client"
require_relative "clients/sentiment/sentimental_client"

require "sentiment_insights/insights/sentiment"
require "sentiment_insights/insights/key_phrases"
require "sentiment_insights/insights/entities"
require "sentiment_insights/insights/topics"

module SentimentInsights
  class Analyzer
    def initialize(provider: SentimentInsights.configuration.provider)
      @provider = provider
    end

    # Sentiment Analysis
    def sentiment(text)
      SentimentInsights::Insights::Sentiment.new(@provider).analyze(text)
    end

    def sentiment_batch(texts)
      SentimentInsights::Insights::Sentiment.new(@provider).analyze_batch(texts)
    end

    # Key Phrase Extraction
    def key_phrases(text)
      SentimentInsights::Insights::KeyPhrases.new(@provider).extract(text)
    end

    def key_phrases_batch(texts, options: {})
      SentimentInsights::Insights::KeyPhrases.new(@provider).extract_batch(texts, options)
    end

    # Entity Recognition
    def entities(text)
      SentimentInsights::Insights::Entities.new(@provider).extract(text)
    end

    def entities_batch(texts, options: {})
      SentimentInsights::Insights::Entities.new(@provider).extract_batch(texts, options)
    end

    # Topic Modeling
    def topics_batch(texts, options: {})
      SentimentInsights::Insights::Topics.new(@provider).model_topics(texts, options)
    end
  end
end
