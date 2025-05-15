require 'aws-sdk-comprehend'
require 'logger'

module SentimentInsights
  module Clients
    module Sentiment
      class AwsComprehendClient
        MAX_BATCH_SIZE = 25  # AWS limit

        def initialize(region: 'us-east-1')
          @client = Aws::Comprehend::Client.new(region: region)
          @logger = Logger.new($stdout)
        end

        # Analyze a batch of entries using AWS Comprehend.
        # @param entries [Array<Hash>] each with :answer key
        # @return [Array<Hash>] each with :label (symbol) and :score (float)
        def analyze_entries(entries, question: nil, prompt: nil, batch_size: nil)
          results = []

          entries.each_slice(MAX_BATCH_SIZE) do |batch|
            texts = batch.map { |entry| entry[:answer].to_s.strip[0...5000] } # max per AWS

            begin
              resp = @client.batch_detect_sentiment({
                                                      text_list: texts,
                                                      language_code: "en"
                                                    })

              resp.result_list.each do |r|
                label = r.sentiment.downcase.to_sym  # :positive, :neutral, :negative, :mixed
                score = compute_score(r.sentiment, r.sentiment_score)
                results << { label: label, score: score }
              end

              # handle errors (will match by index)
              resp.error_list.each do |error|
                @logger.warn "AWS Comprehend error at index #{error.index}: #{error.error_code}"
                results.insert(error.index, { label: :neutral, score: 0.0 })
              end

            rescue Aws::Comprehend::Errors::ServiceError => e
              @logger.error "AWS Comprehend batch error: #{e.message}"
              batch.size.times { results << { label: :neutral, score: 0.0 } }
            end
          end

          results
        end

        private

        # Convert AWS sentiment score hash to a single signed score.
        def compute_score(label, scores)
          case label.upcase
          when "POSITIVE"
            scores.positive.to_f
          when "NEGATIVE"
            -scores.negative.to_f
          when "NEUTRAL"
            0.0
          when "MIXED"
            # Optionally: net positive - negative for mixed
            (scores.positive.to_f - scores.negative.to_f).round(2)
          else
            0.0
          end
        end
      end
    end
  end
end
