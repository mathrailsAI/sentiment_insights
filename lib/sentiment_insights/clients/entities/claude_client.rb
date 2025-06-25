require 'net/http'
require 'uri'
require 'json'
require 'logger'

module SentimentInsights
  module Clients
    module Entities
      class ClaudeClient
        DEFAULT_MODEL   = "claude-3-haiku-20240307"
        DEFAULT_RETRIES = 3

        def initialize(api_key: ENV['CLAUDE_API_KEY'], model: DEFAULT_MODEL, max_retries: DEFAULT_RETRIES)
          @api_key = api_key or raise ArgumentError, "Claude API key is required"
          @model = model
          @max_retries = max_retries
          @logger = Logger.new($stdout)
        end

        def extract_batch(entries, question: nil, prompt: nil)
          responses = []
          entity_map = Hash.new { |h, k| h[k] = [] }

          entries.each_with_index do |entry, index|
            sentence = entry[:answer].to_s.strip
            next if sentence.empty?

            response_id = "r_#{index + 1}"
            entities = extract_entities_from_sentence(sentence, question: question, prompt: prompt)

            responses << {
              id: response_id,
              sentence: sentence,
              segment: entry[:segment] || {}
            }

            entities.each do |ent|
              next if ent[:text].to_s.empty? || ent[:type].to_s.empty?
              key = [ent[:text].downcase, ent[:type]]
              entity_map[key] << response_id
            end
          end

          entity_records = entity_map.map do |(text, type), ref_ids|
            {
              entity: text,
              type: type,
              mentions: ref_ids.uniq,
              summary: nil
            }
          end

          { entities: entity_records, responses: responses }
        end

        private

        def extract_entities_from_sentence(text, question: nil, prompt: nil)
          # Default prompt with interpolation placeholders
          default_prompt = <<~PROMPT
            Extract named entities from this sentence based on the question.
            Return them as a JSON array with each item having "text" and "type" (e.g., PERSON, ORGANIZATION, LOCATION, PRODUCT).
            %{question}
            Sentence: "%{text}"
          PROMPT

          # If a custom prompt is provided, interpolate %{text} and %{question} if present
          if prompt
            interpolated = prompt.dup
            interpolated.gsub!('%{text}', text.to_s)
            interpolated.gsub!('%{question}', question.to_s) if question
            interpolated.gsub!('{text}', text.to_s)
            interpolated.gsub!('{question}', question.to_s) if question
            prompt_to_use = interpolated
          else
            question_line = question ? "Question: #{question}" : ""
            prompt_to_use = default_prompt % { question: question_line, text: text }
          end

          body = build_request_body(prompt_to_use)
          response = post_claude(body)

          begin
            raw_json = response.dig("content", 0, "text").to_s.strip
            JSON.parse(raw_json, symbolize_names: true)
          rescue JSON::ParserError => e
            @logger.warn "Failed to parse entity JSON: #{e.message}"
            []
          end
        end

        def build_request_body(prompt)
          {
            model: @model,
            max_tokens: 1000,
            messages: [{ role: "user", content: prompt }]
          }
        end

        def post_claude(body)
          uri = URI("https://api.anthropic.com/v1/messages")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          attempt = 0
          while attempt < @max_retries
            attempt += 1

            request = Net::HTTP::Post.new(uri)
            request["Content-Type"] = "application/json"
            request["x-api-key"] = @api_key
            request["anthropic-version"] = "2023-06-01"
            request.body = JSON.generate(body)

            begin
              response = http.request(request)
              return JSON.parse(response.body) if response.code.to_i == 200
              @logger.warn "Claude entity extraction failed (#{response.code}): #{response.body}"
            rescue => e
              @logger.error "Error during entity extraction: #{e.class} - #{e.message}"
            end

            sleep(2 ** (attempt - 1)) if attempt < @max_retries
          end

          {}
        end
      end
    end
  end
end