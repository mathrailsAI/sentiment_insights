module SentimentInsights
  module Insights
    # Extracts and summarizes named entities from survey responses
    class Entities
      def initialize(provider: nil, provider_client: nil)
        effective_provider = provider || SentimentInsights.configuration&.provider || :sentimental

        @provider_client = provider_client || case effective_provider
                                              when :openai
                                                require_relative '../clients/entities/open_ai_client'
                                                Clients::Entities::OpenAIClient.new
                                              when :aws
                                                require_relative '../clients/entities/aws_client'
                                                Clients::Entities::AwsClient.new
                                              when :sentimental
                                                raise NotImplementedError, "Entity recognition is not supported for the 'sentimental' provider"
                                              else
                                                raise ArgumentError, "Unsupported provider: #{effective_provider}"
                                              end
      end

      # Extract named entities and build summarized output
      # @param entries [Array<Hash>] each with :answer and optional :segment
      # @return [Hash] { entities: [...], responses: [...] }
      def extract(entries, question: nil)
        entries = entries.to_a
        raw_result = @provider_client.extract_batch(entries, question: question)

        puts "raw_result = #{raw_result}"
        responses = raw_result[:responses] || []
        entities  = raw_result[:entities] || []

        # Index responses by ID
        response_index = responses.each_with_object({}) { |r, h| h[r[:id]] = r }

        enriched_entities = entities.map do |entity_entry|
          mentions = entity_entry[:mentions] || []
          mention_responses = mentions.map { |id| response_index[id] }.compact

          segment_dist = Hash.new { |h, k| h[k] = Hash.new(0) }

          mention_responses.each do |resp|
            (resp[:segment] || {}).each do |seg_key, seg_val|
              segment_dist[seg_key][seg_val] += 1
            end
          end

          {
            entity: entity_entry[:entity],
            type: entity_entry[:type],
            mentions: mentions,
            summary: {
              total_mentions: mentions.size,
              segment_distribution: segment_dist
            }
          }
        end

        {
          entities: enriched_entities,
          responses: responses
        }
      end
    end
  end
end
