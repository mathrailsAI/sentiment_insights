require 'sentimental'

module SentimentInsights
  module Clients
    module Sentiment
      # Client that uses the Sentimental gem for local sentiment analysis.
      class SentimentalClient
        def initialize
          @analyzer = Sentimental.new
          @analyzer.load_defaults  # load built-in positive/negative word scores
        end

        # Analyzes each entry's answer text and returns an array of sentiment results.
        # @param entries [Array<Hash>] An array of response hashes (each with :answer).
        # @param question [String, nil] (unused) Global question context, not needed for local analysis.
        # @return [Array<Hash>] An array of hashes with sentiment classification and score for each entry.
        def analyze_entries(entries, question: nil, prompt: nil, batch_size: nil)
          puts "Inside sentimental"
          entries.map do |entry|
            text = entry[:answer].to_s.strip
            label = @analyzer.sentiment(text)  # :positive, :neutral, or :negative
            score = case label
                    when :positive then 1.0
                    when :negative then -1.0
                    else 0.0
                    end
            { label: label, score: score }
          end
        end
      end
    end
  end
end
