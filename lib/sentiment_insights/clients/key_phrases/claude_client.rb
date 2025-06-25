require 'net/http'
require 'uri'
require 'json'
require 'logger'

module SentimentInsights
  module Clients
    module KeyPhrases
      class ClaudeClient
        DEFAULT_MODEL = "claude-3-haiku-20240307"
        DEFAULT_RETRIES = 3

        def initialize(api_key: ENV['CLAUDE_API_KEY'], model: DEFAULT_MODEL, max_retries: DEFAULT_RETRIES)
          @api_key = api_key or raise ArgumentError, "Claude API key is required"
          @model = model
          @max_retries = max_retries
          @logger = Logger.new($stdout)
        end

        def extract_batch(entries, question: nil, key_phrase_prompt: nil, sentiment_prompt: nil)
          responses = []
          phrase_map = Hash.new { |h, k| h[k] = [] }

          entries.each_with_index do |entry, index|
            sentence = entry[:answer].to_s.strip
            next if sentence.empty?

            response_id = "r_#{index + 1}"
            
            # Extract key phrases
            phrases = extract_key_phrases(sentence, question: question, prompt: key_phrase_prompt)
            
            # Get sentiment for this response
            sentiment = get_sentiment(sentence, prompt: sentiment_prompt)

            responses << {
              id: response_id,
              sentence: sentence,
              sentiment: sentiment,
              segment: entry[:segment] || {}
            }

            phrases.each do |phrase|
              next if phrase.strip.empty?
              phrase_map[phrase.downcase] << response_id
            end
          end

          phrase_records = phrase_map.map do |phrase, ref_ids|
            {
              phrase: phrase,
              mentions: ref_ids.uniq,
              summary: nil
            }
          end

          { phrases: phrase_records, responses: responses }
        end

        private

        def extract_key_phrases(text, question: nil, prompt: nil)
          default_prompt = <<~PROMPT.strip
            Extract the most important key phrases that represent the main ideas or feedback in the sentence below.
            Ignore stop words and return each key phrase in its natural form, comma-separated.

            Question: %{question}

            Text: %{text}
          PROMPT

          if prompt
            interpolated = prompt.dup
            interpolated.gsub!('%{text}', text.to_s)
            interpolated.gsub!('%{question}', question.to_s) if question
            interpolated.gsub!('{text}', text.to_s)
            interpolated.gsub!('{question}', question.to_s) if question
            prompt_to_use = interpolated
          else
            question_line = question ? question.to_s : ""
            prompt_to_use = default_prompt % { question: question_line, text: text }
          end

          body = build_request_body(prompt_to_use)
          response = post_claude(body)

          content = response.dig("content", 0, "text").to_s.strip
          content.split(',').map(&:strip).reject(&:empty?)
        end

        def get_sentiment(text, prompt: nil)
          default_prompt = <<~PROMPT
            Classify the sentiment of this text as Positive, Neutral, or Negative.
            Reply with just the sentiment label.

            Text: "#{text}"
          PROMPT

          prompt_to_use = prompt ? prompt.gsub('%{text}', text) : default_prompt

          body = build_request_body(prompt_to_use)
          response = post_claude(body)

          content = response.dig("content", 0, "text").to_s.strip.downcase
          case content
          when /positive/ then :positive
          when /negative/ then :negative
          else :neutral
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
              @logger.warn "Claude key phrase extraction failed (#{response.code}): #{response.body}"
            rescue => e
              @logger.error "Error during key phrase extraction: #{e.class} - #{e.message}"
            end

            sleep(2 ** (attempt - 1)) if attempt < @max_retries
          end

          {}
        end
      end
    end
  end
end