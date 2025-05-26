require 'net/http'
require 'uri'
require 'json'
require 'logger'

module SentimentInsights
  module Clients
    module Sentiment
      class OpenAIClient
        DEFAULT_MODEL = "gpt-3.5-turbo"
        DEFAULT_RETRIES = 3

        def initialize(api_key: ENV['OPENAI_API_KEY'], model: DEFAULT_MODEL, max_retries: DEFAULT_RETRIES, return_scores: true)
          @api_key = api_key or raise ArgumentError, "OpenAI API key is required"
          @model = model
          @max_retries = max_retries
          @return_scores = return_scores
          @logger = Logger.new($stdout)
        end

        def analyze_entries(entries, question: nil, prompt: nil, batch_size: 50)
          all_sentiments = []

          entries.each_slice(batch_size) do |batch|
            prompt_content = build_prompt_content(batch, question: question, prompt: prompt)
            request_body = {
              model: @model,
              messages: [
                { role: "user", content: prompt_content }
              ],
              temperature: 0.0
            }

            uri = URI("https://api.openai.com/v1/chat/completions")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            response_content = nil
            attempt = 0

            while attempt < @max_retries
              attempt += 1
              request = Net::HTTP::Post.new(uri)
              request["Content-Type"] = "application/json"
              request["Authorization"] = "Bearer #{@api_key}"
              request.body = JSON.generate(request_body)

              begin
                response = http.request(request)
              rescue StandardError => e
                @logger.error "OpenAI API request error: #{e.class} - #{e.message}"
                raise
              end

              status = response.code.to_i
              if status == 429
                @logger.warn "Rate limit (HTTP 429) on attempt #{attempt}. Retrying..."
                sleep(2 ** (attempt - 1))
                next
              elsif status != 200
                @logger.error "Request failed (#{status}): #{response.body}"
                raise "OpenAI API Error: #{status}"
              else
                data = JSON.parse(response.body)
                response_content = data.dig("choices", 0, "message", "content")
                break
              end
            end

            sentiments = parse_sentiments(response_content, batch.size)
            all_sentiments.concat(sentiments)
          end

          all_sentiments
        end

        private

        def build_prompt_content(entries, question: nil, prompt: nil)
          content = ""
          content << "Question: #{question}\n\n" if question

          # Use custom instructions or default
          instructions = prompt || <<~DEFAULT
            For each of the following customer responses, classify the sentiment as Positive, Neutral, or Negative, and assign a score between -1.0 (very negative) and 1.0 (very positive).

            Reply with a numbered list like:
            1. Positive (0.9)
            2. Negative (-0.8)
            3. Neutral (0.0)
          DEFAULT

          content << instructions.strip + "\n\n"

          entries.each_with_index do |entry, index|
            content << "#{index + 1}. \"#{entry[:answer]}\"\n"
          end

          content
        end

        def parse_sentiments(content, expected_count)
          sentiments = []

          content.to_s.strip.split(/\r?\n/).each do |line|
            if line.strip =~ /^\d+[\.:)]?\s*(Positive|Negative|Neutral)\s*\(([-\d\.]+)\)/i
              label = $1.downcase.to_sym
              score = $2.to_f
              sentiments << { label: label, score: score }
            end
          end

          if sentiments.size != expected_count
            @logger.warn "Expected #{expected_count} results, got #{sentiments.size}. Padding with neutral."
            while sentiments.size < expected_count
              sentiments << { label: :neutral, score: 0.0 }
            end
          end

          sentiments.first(expected_count)
        end
      end
    end
  end
end
