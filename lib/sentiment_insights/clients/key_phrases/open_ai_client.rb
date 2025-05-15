require 'net/http'
require 'uri'
require 'json'
require 'logger'
require_relative '../sentiment/open_ai_client'

module SentimentInsights
  module Clients
    module KeyPhrases
      class OpenAIClient
        DEFAULT_MODEL = "gpt-3.5-turbo"
        DEFAULT_RETRIES = 3

        def initialize(api_key: ENV['OPENAI_API_KEY'], model: DEFAULT_MODEL, max_retries: DEFAULT_RETRIES)
          @api_key = api_key or raise ArgumentError, "OpenAI API key is required"
          @model = model
          @max_retries = max_retries
          @logger = Logger.new($stdout)
          @sentiment_client = SentimentInsights::Clients::Sentiment::OpenAIClient.new(api_key: @api_key, model: @model)
        end

        # Extract key phrases from entries and enrich with sentiment
        def extract_batch(entries, question: nil, key_phrase_prompt: nil, sentiment_prompt: nil)
          responses = []
          phrase_map = Hash.new { |h, k| h[k] = [] }

          # Fetch sentiments in batch from sentiment client
          sentiments = @sentiment_client.analyze_entries(entries, question: question, prompt: sentiment_prompt)

          entries.each_with_index do |entry, index|
            sentence = entry[:answer].to_s.strip
            next if sentence.empty?

            response_id = "r_#{index + 1}"
            phrases = extract_phrases_from_sentence(sentence, question: question, prompt: key_phrase_prompt)

            sentiment = sentiments[index] || { label: :neutral }

            responses << {
              id: response_id,
              sentence: sentence,
              sentiment: sentiment[:label],
              segment: entry[:segment] || {}
            }

            phrases.each do |phrase|
              phrase_map[phrase.downcase] << response_id
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

        private

        def extract_phrases_from_sentence(text, question: nil, prompt: nil)
          # Default prompt with interpolation placeholders
          default_prompt = <<~PROMPT
            Extract the most important key phrases that represent the main ideas or feedback in the sentence below.
            Ignore stop words and return each key phrase in its natural form, comma-separated.
            %{question}
            Sentence: "%{text}"
          PROMPT

          # If a custom prompt is provided, attempt to interpolate %{text} and %{question} if present
          if prompt
            interpolated = prompt.dup
            interpolated.gsub!('%{text}', text.to_s)
            interpolated.gsub!('%{question}', question.to_s) if question
            # For compatibility: if “{text}” is used instead of “%{text}”
            interpolated.gsub!('{text}', text.to_s)
            interpolated.gsub!('{question}', question.to_s) if question
            prompt_to_use = interpolated
          else
            question_line = question ? "Question: #{question}" : ""
            prompt_to_use = default_prompt % { question: question_line, text: text }
          end

          body = build_request_body(prompt_to_use)
          response = post_openai(body)

          # The response is expected as a comma- or newline-separated list of key phrases
          parse_phrases(response)
        end

        def build_request_body(prompt)
          {
            model: @model,
            messages: [{ role: "user", content: prompt }],
            temperature: 0.3
          }
        end

        def post_openai(body)
          uri = URI("https://api.openai.com/v1/chat/completions")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          attempt = 0
          while attempt < @max_retries
            attempt += 1

            request = Net::HTTP::Post.new(uri)
            request["Content-Type"] = "application/json"
            request["Authorization"] = "Bearer #{@api_key}"
            request.body = JSON.generate(body)

            begin
              response = http.request(request)
              return JSON.parse(response.body) if response.code.to_i == 200
              @logger.warn "OpenAI request failed (#{response.code}): #{response.body}"
            rescue => e
              @logger.error "OpenAI HTTP error: #{e.class} - #{e.message}"
            end

            sleep(2 ** (attempt - 1)) if attempt < @max_retries
          end

          {}
        end

        def parse_phrases(response)
          text = response.dig("choices", 0, "message", "content").to_s.strip
          text.split(/,|\n/).map(&:strip).reject(&:empty?)
        end
      end
    end
  end
end
