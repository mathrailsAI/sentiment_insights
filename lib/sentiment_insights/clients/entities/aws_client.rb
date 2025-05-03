require 'aws-sdk-comprehend'
require 'logger'

module SentimentInsights
  module Clients
    module Entities
      class AwsClient
        MAX_BATCH_SIZE = 25

        def initialize(region: 'us-east-1')
          @client = Aws::Comprehend::Client.new(region: region)
          @logger = Logger.new($stdout)
        end

        def extract_batch(entries, question: nil)
          responses = []
          entity_map = Hash.new { |h, k| h[k] = [] }

          entries.each_slice(MAX_BATCH_SIZE).with_index do |batch, batch_idx|
            texts = batch.map { |e| e[:answer].to_s.strip[0...5000] }

            begin
              resp = @client.batch_detect_entities({
                                                     text_list: texts,
                                                     language_code: 'en'
                                                   })

              resp.result_list.each_with_index do |res, idx|
                entry_index = (batch_idx * MAX_BATCH_SIZE) + idx
                entry = entries[entry_index]
                sentence = texts[idx]
                response_id = "r_#{entry_index + 1}"

                responses << {
                  id: response_id,
                  sentence: sentence,
                  segment: entry[:segment] || {}
                }

                entities = res.entities.map do |e|
                  {
                    text: e.text.downcase.strip,
                    type: e.type
                  }
                end.uniq { |e| [e[:text], e[:type]] }

                entities.each do |ent|
                  key = [ent[:text], ent[:type]]
                  entity_map[key] << response_id
                end
              end

              resp.error_list.each do |error|
                @logger.warn "AWS entity error at index #{error.index}: #{error.error_code}"
              end

            rescue Aws::Comprehend::Errors::ServiceError => e
              @logger.error "AWS Comprehend error: #{e.message}"
              batch.each_with_index do |entry, i|
                entry_index = (batch_idx * MAX_BATCH_SIZE) + i
                responses << {
                  id: "r_#{entry_index + 1}",
                  sentence: entry[:answer],
                  segment: entry[:segment] || {}
                }
              end
            end
          end

          entities = entity_map.map do |(text, type), ref_ids|
            {
              entity: text,
              type: type,
              mentions: ref_ids.uniq,
              summary: nil
            }
          end

          { entities: entities, responses: responses }
        end
      end
    end
  end
end
