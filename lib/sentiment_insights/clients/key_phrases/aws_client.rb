require 'aws-sdk-comprehend'
require 'logger'

module SentimentInsights
  module Clients
    module KeyPhrases
      class AwsClient
        MAX_BATCH_SIZE = 25

        def initialize(region: 'us-east-1')
          @comprehend = Aws::Comprehend::Client.new(region: region)
          @logger = Logger.new($stdout)
        end

        def extract_batch(entries, question: nil, key_phrase_prompt: nil, sentiment_prompt: nil)
          responses = []
          phrase_map = Hash.new { |h, k| h[k] = [] }

          # Split into batches for AWS Comprehend
          entries.each_slice(MAX_BATCH_SIZE).with_index do |batch, batch_idx|
            texts = batch.map { |e| e[:answer].to_s.strip[0...5000] }

            begin
              phrase_resp = @comprehend.batch_detect_key_phrases({
                                                                   text_list: texts,
                                                                   language_code: 'en'
                                                                 })

              sentiment_resp = @comprehend.batch_detect_sentiment({
                                                                    text_list: texts,
                                                                    language_code: 'en'
                                                                  })

              phrase_resp.result_list.each_with_index do |phrase_result, idx|
                sentiment_result = sentiment_resp.result_list.find { |s| s.index == phrase_result.index }
                sentiment_label = sentiment_result&.sentiment&.downcase&.to_sym || :neutral

                entry_index = (batch_idx * MAX_BATCH_SIZE) + idx
                entry = entries[entry_index]
                sentence = texts[idx]
                response_id = "r_#{entry_index + 1}"

                responses << {
                  id: response_id,
                  sentence: sentence,
                  sentiment: sentiment_label,
                  segment: entry[:segment] || {}
                }

                phrases = phrase_result.key_phrases.map { |p| p.text.downcase.strip }.uniq
                phrases.each { |phrase| phrase_map[phrase] << response_id }
              end

              phrase_resp.error_list.each do |error|
                @logger.warn "AWS KeyPhrase error at index #{error.index}: #{error.error_code}"
              end

              sentiment_resp.error_list.each do |error|
                @logger.warn "AWS Sentiment error at index #{error.index}: #{error.error_code}"
              end

            rescue Aws::Comprehend::Errors::ServiceError => e
              @logger.error "AWS Comprehend batch error: #{e.message}"
              batch.each_with_index do |entry, i|
                entry_index = (batch_idx * MAX_BATCH_SIZE) + i
                responses << {
                  id: "r_#{entry_index + 1}",
                  sentence: entry[:answer],
                  sentiment: :neutral,
                  segment: entry[:segment] || {}
                }
              end
            end
          end

          phrases = phrase_map.map do |phrase, ref_ids|
            {
              phrase: phrase,
              mentions: ref_ids.uniq,
              summary: nil
            }
          end

          { phrases: phrases, responses: responses }
        end
      end
    end
  end
end
