require_relative 'base_exporter'

module SentimentInsights
  module Export
    class CsvExporter < BaseExporter
      def export(filename = nil)
        filename ||= generate_filename("csv")
        
        # Apply filters if specified
        filtered_result = apply_filters(@result)
        
        CSV.open(filename, "w", encoding: options[:encoding]) do |csv|
          write_main_data(csv, filtered_result)
          
          if options[:include_summary]
            write_empty_row(csv)
            write_summary_section(csv)
          end
          
          if options[:include_segments]
            write_empty_row(csv)
            write_segment_section(csv)
          end
        end
        
        filename
      end

      private

      def write_main_data(csv, data)
        # Write headers
        headers = build_headers
        csv << headers
        
        # Write response data
        responses = case analysis_type
                   when :sentiment
                     data[:responses] || []
                   when :entities
                     build_entity_response_rows(data)
                   when :key_phrases
                     build_phrase_response_rows(data)
                   else
                     data[:responses] || []
                   end

        write_response_rows(csv, responses)
      end

      def write_response_rows(csv, responses)
        segment_keys = detect_all_segment_keys
        
        responses.each_with_index do |response, index|
          row = build_base_row(response, index)
          row += extract_segment_values(response[:segment], segment_keys)
          row << format_timestamp if options[:include_timestamp]
          csv << row
        end
      end

      def build_entity_response_rows(data)
        responses = data[:responses] || []
        entities_by_response = build_entities_lookup(data[:entities] || [])
        
        responses.map do |response|
          response_entities = entities_by_response[response[:id]] || []
          response.merge(entities_found: format_entities_list(response_entities))
        end
      end

      def build_phrase_response_rows(data)
        responses = data[:responses] || []
        phrases_by_response = build_phrases_lookup(data[:phrases] || [])
        
        responses.map do |response|
          response_phrases = phrases_by_response[response[:id]] || []
          response.merge(phrases_found: response_phrases.join(","))
        end
      end

      def build_entities_lookup(entities)
        lookup = Hash.new { |h, k| h[k] = [] }
        
        entities.each do |entity|
          mentions = entity[:mentions] || []
          mentions.each do |response_id|
            lookup[response_id] << {
              text: entity[:entity],
              type: entity[:type]
            }
          end
        end
        
        lookup
      end

      def build_phrases_lookup(phrases)
        lookup = Hash.new { |h, k| h[k] = [] }
        
        phrases.each do |phrase|
          mentions = phrase[:mentions] || []
          mentions.each do |response_id|
            lookup[response_id] << phrase[:phrase]
          end
        end
        
        lookup
      end

      def format_entities_list(entities)
        entities.map { |e| "#{e[:text]}:#{e[:type]}" }.join(",")
      end

      def write_summary_section(csv)
        csv << ["SUMMARY STATISTICS"]
        
        summary_data = extract_summary_data
        summary_data.each do |key, value|
          csv << [key, value]
        end
      end

      def write_segment_section(csv)
        segment_data = extract_segment_data
        return if segment_data.empty?
        
        csv << ["SEGMENT ANALYSIS"]
        csv << ["Segment Type", "Segment Value", "Total Count", "Positive %", "Neutral %", "Negative %", "Net Score"]
        
        segment_data.each do |segment|
          csv << [
            segment[:segment_type],
            segment[:segment_value],
            segment[:total_count],
            segment[:positive_percentage],
            segment[:neutral_percentage],
            segment[:negative_percentage],
            segment[:net_score]
          ]
        end
      end

      def write_empty_row(csv)
        csv << []
      end

      # Enhanced entity export format
      def write_entity_details_section(csv, data)
        return unless analysis_type == :entities && data[:entities]
        
        write_empty_row(csv)
        csv << ["ENTITY DETAILS"]
        csv << ["Entity", "Type", "Total Mentions", "Response IDs", "Segment Distribution"]
        
        data[:entities].each do |entity|
          segment_dist = build_segment_distribution(entity[:mentions] || [])
          csv << [
            entity[:entity],
            entity[:type],
            entity[:mentions]&.length || 0,
            (entity[:mentions] || []).join(","),
            format_segment_distribution(segment_dist)
          ]
        end
      end

      def write_phrase_details_section(csv, data)
        return unless analysis_type == :key_phrases && data[:phrases]
        
        write_empty_row(csv)
        csv << ["PHRASE DETAILS"]
        csv << ["Phrase", "Total Mentions", "Response IDs", "Sentiment Distribution", "Segment Distribution"]
        
        data[:phrases].each do |phrase|
          sentiment_dist = build_phrase_sentiment_distribution(phrase[:mentions] || [])
          segment_dist = build_segment_distribution(phrase[:mentions] || [])
          
          csv << [
            phrase[:phrase],
            phrase[:mentions]&.length || 0,
            (phrase[:mentions] || []).join(","),
            format_sentiment_distribution(sentiment_dist),
            format_segment_distribution(segment_dist)
          ]
        end
      end

      def build_segment_distribution(response_ids)
        distribution = Hash.new { |h, k| h[k] = Hash.new(0) }
        
        response_ids.each do |response_id|
          response = find_response_by_id(response_id)
          next unless response && response[:segment]
          
          response[:segment].each do |segment_type, segment_value|
            distribution[segment_type][segment_value] += 1
          end
        end
        
        distribution
      end

      def build_phrase_sentiment_distribution(response_ids)
        distribution = Hash.new(0)
        
        response_ids.each do |response_id|
          response = find_response_by_id(response_id)
          next unless response
          
          sentiment = response[:sentiment] || response[:sentiment_label] || "neutral"
          distribution[sentiment.to_s] += 1
        end
        
        distribution
      end

      def find_response_by_id(response_id)
        responses = extract_responses_data
        responses.find { |r| r[:id] == response_id }
      end

      def format_sentiment_distribution(distribution)
        distribution.map { |sentiment, count| "#{sentiment}:#{count}" }.join(",")
      end

      def format_segment_distribution(distribution)
        parts = []
        distribution.each do |segment_type, values|
          values.each do |value, count|
            parts << "#{segment_type}_#{value}:#{count}"
          end
        end
        parts.join(",")
      end

      # Override build_base_row for entities and key phrases
      def build_base_row(response, index)
        response_id = response[:id] || "r_#{index + 1}"
        text = response[:answer] || response[:sentence] || ""

        case analysis_type
        when :sentiment
          sentiment_label = response[:sentiment_label] || response[:sentiment] || ""
          sentiment_score = response[:sentiment_score] || 0.0
          [response_id, text, sentiment_label.to_s, sentiment_score.to_s]
        when :entities
          entities = response[:entities_found] || ""
          [response_id, text, entities]
        when :key_phrases
          sentiment = response[:sentiment] || ""
          sentiment_score = response[:sentiment_score] || 0.0
          phrases = response[:phrases_found] || ""
          [response_id, text, sentiment, sentiment_score, phrases]
        else
          [response_id, text]
        end
      end
    end
  end
end