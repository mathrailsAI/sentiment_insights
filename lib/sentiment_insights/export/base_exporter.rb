require 'csv'
require 'time'

module SentimentInsights
  module Export
    class BaseExporter
      attr_reader :result, :options, :analysis_type

      def initialize(result, options = {})
        @result = result
        @options = default_options.merge(options)
        @analysis_type = detect_analysis_type(result)
      end

      protected

      def default_options
        {
          include_summary: true,
          include_segments: true,
          include_timestamp: true,
          timestamp_format: "%Y-%m-%d %H:%M:%S UTC",
          encoding: "UTF-8"
        }
      end

      def detect_analysis_type(result)
        return :entities if result.key?(:entities)
        return :key_phrases if result.key?(:phrases)
        return :sentiment if result.key?(:global_summary) || result.key?(:responses)
        :unknown
      end

      def generate_filename(extension)
        base_name = "#{analysis_type}_analysis"
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        "#{base_name}_#{timestamp}.#{extension}"
      end

      # Dynamic segment column detection
      def detect_all_segment_keys
        responses = extract_responses_data
        all_keys = Set.new

        responses.each do |response|
          segment_data = response[:segment] || response.dig(:segment) || {}
          flatten_hash_keys(segment_data, all_keys)
        end

        all_keys.to_a.sort
      end

      def flatten_hash_keys(hash, keys_set, prefix = "")
        return unless hash.is_a?(Hash)

        hash.each do |key, value|
          full_key = prefix.empty? ? key.to_s : "#{prefix}_#{key}"
          
          if value.is_a?(Hash)
            flatten_hash_keys(value, keys_set, full_key)
          else
            keys_set << full_key
          end
        end
      end

      def extract_segment_values(segment_data, all_keys)
        return Array.new(all_keys.length) if segment_data.nil?

        flattened = flatten_hash(segment_data)
        all_keys.map { |key| flattened[key] || "" }
      end

      def flatten_hash(hash, prefix = "")
        return {} unless hash.is_a?(Hash)

        result = {}
        hash.each do |key, value|
          full_key = prefix.empty? ? key.to_s : "#{prefix}_#{key}"
          
          if value.is_a?(Hash)
            result.merge!(flatten_hash(value, full_key))
          else
            result[full_key] = value
          end
        end
        result
      end

      # Extract responses data based on analysis type
      def extract_responses_data
        case analysis_type
        when :sentiment
          result[:responses] || []
        when :entities
          result[:responses] || []
        when :key_phrases
          result[:responses] || []
        else
          []
        end
      end

      # Build headers for CSV/Excel
      def build_headers
        base_headers = case analysis_type
                      when :sentiment
                        %w[response_id text sentiment_label sentiment_score]
                      when :entities
                        %w[response_id text entities_found]
                      when :key_phrases
                        %w[response_id text sentiment sentiment_score key_phrases_found]
                      else
                        %w[response_id text]
                      end

        # Add dynamic segment columns
        segment_keys = detect_all_segment_keys
        segment_headers = segment_keys.map { |key| "segment_#{key}" }

        headers = base_headers + segment_headers
        headers << "timestamp" if options[:include_timestamp]
        headers
      end

      # Build row data for responses
      def build_response_rows
        responses = extract_responses_data
        segment_keys = detect_all_segment_keys

        responses.map.with_index do |response, index|
          row = build_base_row(response, index)
          row += extract_segment_values(response[:segment], segment_keys)
          row << format_timestamp if options[:include_timestamp]
          row
        end
      end

      def build_base_row(response, index)
        response_id = response[:id] || "r_#{index + 1}"
        text = response[:sentence] || response[:answer] || ""

        case analysis_type
        when :sentiment
          sentiment_label = response[:sentiment_label] || response[:sentiment] || ""
          sentiment_score = response[:sentiment_score] || 0.0
          [response_id, text, sentiment_label, sentiment_score]
        when :entities
          entities = format_entities_for_export(response)
          [response_id, text, entities]
        when :key_phrases
          sentiment = response[:sentiment] || ""
          sentiment_score = response[:sentiment_score] || 0.0
          phrases = format_phrases_for_export(response)
          [response_id, text, sentiment, sentiment_score, phrases]
        else
          [response_id, text]
        end
      end

      def format_entities_for_export(response)
        # This would be populated by entity extraction results
        # Format: "entity1:TYPE1,entity2:TYPE2"
        return "" unless response[:entities]
        
        response[:entities].map do |entity|
          "#{entity[:text]}:#{entity[:type]}"
        end.join(",")
      end

      def format_phrases_for_export(response)
        # This would be populated by key phrase extraction results
        return "" unless response[:phrases]
        
        response[:phrases].join(",")
      end

      def format_timestamp
        Time.now.strftime(options[:timestamp_format])
      end

      # Summary statistics extraction
      def extract_summary_data
        case analysis_type
        when :sentiment
          extract_sentiment_summary
        when :entities
          extract_entities_summary
        when :key_phrases
          extract_phrases_summary
        else
          {}
        end
      end

      def extract_sentiment_summary
        return {} unless result[:global_summary]

        summary = result[:global_summary]
        {
          "Total Responses" => summary[:total_count],
          "Positive Count" => summary[:positive_count],
          "Neutral Count" => summary[:neutral_count],
          "Negative Count" => summary[:negative_count],
          "Positive Percentage" => "#{summary[:positive_percentage]}%",
          "Neutral Percentage" => "#{summary[:neutral_percentage]}%",
          "Negative Percentage" => "#{summary[:negative_percentage]}%",
          "Net Sentiment Score" => summary[:net_sentiment_score]
        }
      end

      def extract_entities_summary
        return {} unless result[:entities]

        entities = result[:entities]
        entity_types = entities.group_by { |e| e[:type] }
        
        summary = {
          "Total Unique Entities" => entities.length,
          "Total Mentions" => entities.sum { |e| e[:mentions]&.length || 0 }
        }

        entity_types.each do |type, entities_of_type|
          summary["#{type.capitalize} Count"] = entities_of_type.length
        end

        if entities.any?
          most_mentioned = entities.max_by { |e| e[:mentions]&.length || 0 }
          summary["Most Mentioned Entity"] = "#{most_mentioned[:entity]} (#{most_mentioned[:mentions]&.length || 0} times)"
        end

        summary
      end

      def extract_phrases_summary
        return {} unless result[:phrases]

        phrases = result[:phrases]
        total_mentions = phrases.sum { |p| p[:mentions]&.length || 0 }
        
        {
          "Total Unique Phrases" => phrases.length,
          "Total Mentions" => total_mentions,
          "Average Mentions per Phrase" => phrases.empty? ? 0 : (total_mentions.to_f / phrases.length).round(2)
        }
      end

      # Segment analysis data
      def extract_segment_data
        return [] unless result[:segment_summary] && options[:include_segments]

        segment_data = []
        result[:segment_summary].each do |segment_type, segments|
          next if segment_type == :top_positive_comments || segment_type == :top_negative_comments

          segments.each do |segment_value, stats|
            segment_data << {
              segment_type: segment_type.to_s.gsub('_', ' ').split.map(&:capitalize).join(' '),
              segment_value: segment_value,
              total_count: stats[:total_count],
              positive_percentage: "#{stats[:positive_percentage]}%",
              neutral_percentage: "#{stats[:neutral_percentage]}%", 
              negative_percentage: "#{stats[:negative_percentage]}%",
              net_score: stats[:net_sentiment_score]
            }
          end
        end

        segment_data
      end

      # Apply filters if specified
      def apply_filters(data)
        return data unless options[:filter]

        filtered_data = data.dup
        filter_options = options[:filter] || {}

        # Filter by sentiment
        if filter_options[:sentiment]
          allowed_sentiments = Array(filter_options[:sentiment])
          filtered_data[:responses] = filtered_data[:responses]&.select do |response|
            sentiment = response[:sentiment_label] || response[:sentiment]
            allowed_sentiments.include?(sentiment&.to_sym)
          end
        end

        # Filter by segments
        if filter_options[:segments]
          filtered_data[:responses] = filtered_data[:responses]&.select do |response|
            segment = response[:segment] || {}
            filter_options[:segments].all? do |key, values|
              Array(values).include?(segment[key])
            end
          end
        end

        # Filter by date range (if timestamp is available)
        if filter_options[:date_range] && filter_options[:date_range].is_a?(Range)
          # This would require timestamp data in responses
          # Implementation would depend on timestamp format
        end

        filtered_data
      end
    end
  end
end