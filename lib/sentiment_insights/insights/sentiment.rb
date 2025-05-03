require_relative '../clients/sentiment/open_ai_client'
require_relative '../clients/sentiment/sentimental_client'

module SentimentInsights
  module Insights
    # Analyzes sentiment of survey responses and produces summarized insights.
    class Sentiment
      DEFAULT_TOP_COUNT = 5

      # Initialize with a specified provider or a concrete provider client.
      # If no provider is given, default to the Sentimental (local) provider.
      def initialize(provider: nil, provider_client: nil, top_count: DEFAULT_TOP_COUNT)
        effective_provider = provider || SentimentInsights.configuration&.provider || :sentimental
        @provider_client = provider_client || case effective_provider
                                              when :openai
                                                Clients::Sentiment::OpenAIClient.new
                                              when :aws
                                                require_relative '../clients/sentiment/aws_comprehend_client'
                                                Clients::Sentiment::AwsComprehendClient.new
                                              else
                                                Clients::Sentiment::SentimentalClient.new
                                              end
        @top_count = top_count
      end

      # Analyze a batch of entries and return sentiment insights.
      # @param entries [Array<Hash>] An array of response hashes, each with :answer and :segment.
      # @param question [String, nil] Optional global question text or metadata for context.
      # @return [Hash] Summary of sentiment analysis (global, segment-wise, top comments, and annotated responses).
      def analyze(entries, question: nil)
        # Ensure entries is an array of hashes with required keys
        entries = entries.to_a
        # Get sentiment results for each entry from the provider client
        results = @provider_client.analyze_entries(entries, question: question)

        # Combine original entries with sentiment results
        annotated_responses = entries.each_with_index.map do |entry, idx|
          res = results[idx] || {}
          {
            answer:  entry[:answer],
            segment: entry[:segment] || {},
            sentiment_label: res[:label],
            sentiment_score: res[:score]
          }
        end

        global_summary = prepare_global_summary(annotated_responses)
        segment_summary = prepare_segment_summary(annotated_responses)

        top_positive_comments, top_negative_comments = top_comments(annotated_responses)

        # Assemble the result hash
        {
          global_summary:       global_summary,
          segment_summary:      segment_summary,
          top_positive_comments: top_positive_comments,
          top_negative_comments: top_negative_comments,
          responses:            annotated_responses
        }
      end

      private

      def prepare_global_summary(annotated_responses)
        # Global sentiment counts
        total_count    = annotated_responses.size
        positive_count = annotated_responses.count { |r| r[:sentiment_label] == :positive }
        negative_count = annotated_responses.count { |r| r[:sentiment_label] == :negative }
        neutral_count  = annotated_responses.count { |r| r[:sentiment_label] == :neutral }

        # Global percentages (avoid division by zero)
        positive_pct = total_count > 0 ? (positive_count.to_f * 100.0 / total_count) : 0.0
        negative_pct = total_count > 0 ? (negative_count.to_f * 100.0 / total_count) : 0.0
        neutral_pct  = total_count > 0 ? (neutral_count.to_f * 100.0 / total_count) : 0.0

        # Net sentiment score = positive% - negative%
        net_sentiment = positive_pct - negative_pct

        {
          total_count:         total_count,
          positive_count:      positive_count,
          neutral_count:       neutral_count,
          negative_count:      negative_count,
          positive_percentage: positive_pct,
          neutral_percentage:  neutral_pct,
          negative_percentage: negative_pct,
          net_sentiment_score: net_sentiment
        }
      end

      def prepare_segment_summary(annotated_responses)
        # Per-segment sentiment summary (for each segment attribute and value)
        segment_summary = {}
        annotated_responses.each do |resp|
          resp[:segment].each do |seg_key, seg_val|
            segment_summary[seg_key] ||= {}
            segment_summary[seg_key][seg_val] ||= {
              total_count:         0,
              positive_count:      0,
              neutral_count:       0,
              negative_count:      0,
              positive_percentage: 0.0,
              neutral_percentage:  0.0,
              negative_percentage: 0.0,
              net_sentiment_score: 0.0
            }
            group = segment_summary[seg_key][seg_val]
            # Increment counts per sentiment
            group[:total_count] += 1
            case resp[:sentiment_label]
            when :positive then group[:positive_count] += 1
            when :neutral  then group[:neutral_count]  += 1
            when :negative then group[:negative_count] += 1
            end
          end
        end

        # Compute percentages and net sentiment for each segment group
        segment_summary.each do |_, groups|
          groups.each do |_, stats|
            total = stats[:total_count]
            if total > 0
              stats[:positive_percentage] = (stats[:positive_count].to_f * 100.0 / total)
              stats[:neutral_percentage]  = (stats[:neutral_count].to_f * 100.0 / total)
              stats[:negative_percentage] = (stats[:negative_count].to_f * 100.0 / total)
              stats[:net_sentiment_score] = stats[:positive_percentage] - stats[:negative_percentage]
            else
              stats[:positive_percentage] = stats[:neutral_percentage] = stats[:negative_percentage] = 0.0
              stats[:net_sentiment_score] = 0.0
            end
          end
        end
      end

      # Identify top N positive and negative responses by score
      def top_comments(annotated_responses)
        top_positive = annotated_responses.select { |r| r[:sentiment_label] == :positive }
        top_positive.sort_by! { |r| -r[:sentiment_score].to_f }  # descending by score (if all 1.0, order remains as is)
        top_negative = annotated_responses.select { |r| r[:sentiment_label] == :negative }
        top_negative.sort_by! { |r| r[:sentiment_score].to_f }   # ascending by score (more negative first, since score is -1.0)

        top_positive_comments = top_positive.first(@top_count).map do |r|
          { answer: r[:answer], score: r[:sentiment_score] }
        end
        top_negative_comments = top_negative.first(@top_count).map do |r|
          { answer: r[:answer], score: r[:sentiment_score] }
        end
        [top_positive_comments, top_negative_comments]
      end
    end
  end
end
