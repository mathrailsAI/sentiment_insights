require_relative 'base_exporter'
require 'json'

module SentimentInsights
  module Export
    class JsonExporter < BaseExporter
      def export(filename = nil)
        filename ||= generate_filename("json")
        
        # Apply filters if specified
        filtered_result = apply_filters(@result)
        
        structured_data = build_json_structure(filtered_result)
        
        if filename
          File.write(filename, JSON.pretty_generate(structured_data))
          filename
        else
          structured_data  # Return data directly for API responses
        end
      end

      # Return JSON string without writing to file
      def to_json_string
        structured_data = build_json_structure(apply_filters(@result))
        JSON.pretty_generate(structured_data)
      end

      # Return raw hash structure (for API responses)
      def to_hash
        build_json_structure(apply_filters(@result))
      end

      private

      def build_json_structure(data)
        {
          metadata: build_metadata,
          analysis: build_analysis_data(data),
          export_info: build_export_info
        }
      end

      def build_metadata
        {
          export_timestamp: Time.now.utc.iso8601,
          analysis_type: analysis_type.to_s,
          total_responses: extract_responses_data.count,
          provider_used: detect_provider
        }
      end

      def build_analysis_data(data)
        case analysis_type
        when :sentiment
          build_sentiment_json(data)
        when :entities
          build_entities_json(data)
        when :key_phrases
          build_phrases_json(data)
        else
          data
        end
      end

      def build_sentiment_json(data)
        result = {
          responses: format_responses_for_json(data[:responses] || [])
        }
        
        if options[:include_summary] && data[:global_summary]
          result[:global_summary] = data[:global_summary]
        end
        
        if options[:include_segments] && data[:segment_summary]
          result[:segment_summary] = format_segment_summary_for_json(data[:segment_summary])
        end
        
        if data[:top_positive_comments]
          result[:top_positive_comments] = data[:top_positive_comments]
        end
        
        if data[:top_negative_comments]
          result[:top_negative_comments] = data[:top_negative_comments]
        end
        
        result
      end

      def build_entities_json(data)
        {
          entities: format_entities_for_json(data[:entities] || []),
          responses: format_responses_for_json(data[:responses] || [])
        }
      end

      def build_phrases_json(data)
        {
          phrases: format_phrases_for_json(data[:phrases] || []),
          responses: format_responses_for_json(data[:responses] || [])
        }
      end

      def format_responses_for_json(responses)
        responses.map do |response|
          formatted = {
            id: response[:id] || "r_#{responses.index(response) + 1}",
            text: response[:sentence] || response[:answer],
            segment: response[:segment] || {}
          }
          
          # Add analysis-specific fields
          case analysis_type
          when :sentiment
            formatted[:sentiment] = {
              label: response[:sentiment_label] || response[:sentiment],
              score: response[:sentiment_score] || 0.0
            }
          when :key_phrases
            formatted[:sentiment] = {
              label: response[:sentiment],
              score: response[:sentiment_score] || 0.0
            }
          end
          
          formatted[:timestamp] = format_timestamp if options[:include_timestamp]
          formatted
        end
      end

      def format_entities_for_json(entities)
        entities.map do |entity|
          {
            entity: entity[:entity],
            type: entity[:type],
            mentions: entity[:mentions] || [],
            summary: entity[:summary] || {}
          }
        end
      end

      def format_phrases_for_json(phrases)
        phrases.map do |phrase|
          {
            phrase: phrase[:phrase],
            mentions: phrase[:mentions] || [],
            summary: phrase[:summary] || {}
          }
        end
      end

      def format_segment_summary_for_json(segment_summary)
        formatted = {}
        segment_summary.each do |segment_type, segments|
          next if [:top_positive_comments, :top_negative_comments].include?(segment_type)
          
          formatted[segment_type] = {}
          segments.each do |segment_value, stats|
            formatted[segment_type][segment_value] = stats
          end
        end
        formatted
      end

      def build_export_info
        {
          format: "json",
          options_used: @options,
          filters_applied: @options[:filter] || {},
          generated_at: Time.now.utc.iso8601
        }
      end

      def detect_provider
        # Try to detect which provider was used based on result structure
        return "unknown" unless @result.is_a?(Hash)
        
        # This could be enhanced based on provider-specific signatures
        "auto-detected"
      end
    end
  end
end