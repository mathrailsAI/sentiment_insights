require_relative '../clients/key_phrases/open_ai_client'
require_relative '../clients/key_phrases/aws_client'

module SentimentInsights
  module Insights
    # Extracts and summarizes key phrases from survey responses
    class KeyPhrases
      def initialize(provider: nil, provider_client: nil)
        effective_provider = provider || SentimentInsights.configuration&.provider || :sentimental

        @provider_client = provider_client || case effective_provider
                                              when :openai
                                                Clients::KeyPhrases::OpenAIClient.new
                                              when :aws
                                                Clients::KeyPhrases::AwsClient.new
                                              when :sentimental
                                                raise NotImplementedError, "Key phrase extraction is not supported for the 'sentimental' provider"
                                              else
                                                raise ArgumentError, "Unsupported provider: #{effective_provider}"
                                              end
      end

      # Extract key phrases and build a normalized, summarized output
      # @param entries [Array<Hash>] each with :answer and optional :segment
      # @param question [String, nil] optional context
      # @return [Hash] { phrases: [...], responses: [...] }
      def extract(entries, question: nil, key_phrase_prompt: nil, sentiment_prompt: nil)
        entries = entries.to_a
        raw_result = @provider_client.extract_batch(entries, question: question, key_phrase_prompt: key_phrase_prompt, sentiment_prompt: sentiment_prompt)

        responses = raw_result[:responses] || []
        phrases  = raw_result[:phrases] || []
        puts "phrases = #{phrases}"

        puts "responses = #{responses}"
        # Index responses by id for lookup
        response_index = {}
        responses.each do |r|
          response_index[r[:id]] = r
        end

        enriched_phrases = phrases.map do |phrase_entry|
          mentions = phrase_entry[:mentions] || []
          mention_responses = mentions.map { |id| response_index[id] }.compact

          sentiment_dist = Hash.new(0)
          segment_dist = Hash.new { |h, k| h[k] = Hash.new(0) }

          mention_responses.each do |resp|
            sentiment = resp[:sentiment] || :neutral
            sentiment_dist[sentiment] += 1

            (resp[:segment] || {}).each do |seg_key, seg_val|
              segment_dist[seg_key][seg_val] += 1
            end
          end

          {
            phrase: phrase_entry[:phrase],
            mentions: mentions,
            summary: {
              total_mentions: mentions.size,
              sentiment_distribution: {
                positive: sentiment_dist[:positive],
                negative: sentiment_dist[:negative],
                neutral:  sentiment_dist[:neutral]
              },
              segment_distribution: segment_dist
            }
          }
        end

        {
          phrases: enriched_phrases,
          responses: responses
        }
      end
    end
  end
end