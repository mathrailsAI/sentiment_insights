require_relative 'base_exporter'

begin
  require 'rubyXL'
rescue LoadError
  puts "Warning: rubyXL gem not found. Excel export will not be available."
  puts "Install with: gem install rubyXL"
end

module SentimentInsights
  module Export
    class ExcelExporter < BaseExporter
      def export(filename = nil)
        raise "rubyXL gem is required for Excel export" unless defined?(RubyXL)
        
        filename ||= generate_filename("xlsx")
        
        # Apply filters if specified
        filtered_result = apply_filters(@result)
        
        workbook = RubyXL::Workbook.new
        
        # Remove the default worksheet
        workbook.worksheets.delete_at(0)
        
        # Create worksheets based on analysis type and options
        create_responses_sheet(workbook, filtered_result)
        create_summary_sheet(workbook) if options[:include_summary]
        create_segments_sheet(workbook) if options[:include_segments]
        
        case analysis_type
        when :entities
          create_entities_sheet(workbook, filtered_result)
        when :key_phrases
          create_phrases_sheet(workbook, filtered_result)
        end
        
        workbook.write(filename)
        filename
      end

      private

      def create_responses_sheet(workbook, data)
        worksheet = workbook.add_worksheet("Responses")
        
        # Write headers
        headers = build_headers
        write_excel_row(worksheet, 0, headers, bold: true)
        
        # Write data rows
        write_response_data(worksheet, data, start_row: 1)
        
        # Auto-size columns
        auto_size_columns(worksheet, headers.length)
        
        worksheet
      end

      def create_summary_sheet(workbook)
        worksheet = workbook.add_worksheet("Summary")
        
        summary_data = extract_summary_data
        row = 0
        
        # Title
        worksheet.add_cell(row, 0, "SUMMARY STATISTICS")
        row += 2
        
        # Summary data
        summary_data.each do |key, value|
          worksheet.add_cell(row, 0, key)
          worksheet.add_cell(row, 1, value)
          row += 1
        end
        
        auto_size_columns(worksheet, 2)
        worksheet
      end

      def create_segments_sheet(workbook)
        segment_data = extract_segment_data
        return unless segment_data.any?
        
        worksheet = workbook.add_worksheet("Segment Analysis")
        
        # Title
        worksheet.add_cell(0, 0, "SEGMENT ANALYSIS")
        
        # Headers
        headers = ["Segment Type", "Segment Value", "Total Count", "Positive %", "Neutral %", "Negative %", "Net Score"]
        write_excel_row(worksheet, 2, headers, bold: true)
        
        # Data
        segment_data.each_with_index do |segment, index|
          row = 3 + index
          write_excel_row(worksheet, row, [
            segment[:segment_type],
            segment[:segment_value],
            segment[:total_count],
            segment[:positive_percentage],
            segment[:neutral_percentage],
            segment[:negative_percentage],
            segment[:net_score]
          ])
        end
        
        auto_size_columns(worksheet, headers.length)
        worksheet
      end

      def create_entities_sheet(workbook, data)
        return unless data[:entities]
        
        worksheet = workbook.add_worksheet("Entity Details")
        
        # Title
        worksheet.add_cell(0, 0, "ENTITY ANALYSIS")
        
        # Headers
        headers = ["Entity", "Type", "Total Mentions", "Response IDs", "Segment Distribution"]
        write_excel_row(worksheet, 2, headers, bold: true)
        
        # Data
        data[:entities].each_with_index do |entity, index|
          row = 3 + index
          segment_dist = build_segment_distribution(entity[:mentions] || [])
          
          write_excel_row(worksheet, row, [
            entity[:entity],
            entity[:type],
            entity[:mentions]&.length || 0,
            (entity[:mentions] || []).join(", "),
            format_segment_distribution(segment_dist)
          ])
        end
        
        auto_size_columns(worksheet, headers.length)
        worksheet
      end

      def create_phrases_sheet(workbook, data)
        return unless data[:phrases]
        
        worksheet = workbook.add_worksheet("Phrase Details")
        
        # Title
        worksheet.add_cell(0, 0, "KEY PHRASE ANALYSIS")
        
        # Headers
        headers = ["Phrase", "Total Mentions", "Response IDs", "Sentiment Distribution", "Segment Distribution"]
        write_excel_row(worksheet, 2, headers, bold: true)
        
        # Data
        data[:phrases].each_with_index do |phrase, index|
          row = 3 + index
          sentiment_dist = build_phrase_sentiment_distribution(phrase[:mentions] || [])
          segment_dist = build_segment_distribution(phrase[:mentions] || [])
          
          write_excel_row(worksheet, row, [
            phrase[:phrase],
            phrase[:mentions]&.length || 0,
            (phrase[:mentions] || []).join(", "),
            format_sentiment_distribution(sentiment_dist),
            format_segment_distribution(segment_dist)
          ])
        end
        
        auto_size_columns(worksheet, headers.length)
        worksheet
      end

      def write_response_data(worksheet, data, start_row: 0)
        segment_keys = detect_all_segment_keys
        
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

        responses.each_with_index do |response, index|
          row = start_row + index
          row_data = build_base_row(response, index)
          row_data += extract_segment_values(response[:segment], segment_keys)
          row_data << format_timestamp if options[:include_timestamp]
          
          write_excel_row(worksheet, row, row_data)
        end
      end

      def write_excel_row(worksheet, row_index, data, bold: false)
        data.each_with_index do |value, col_index|
          worksheet.add_cell(row_index, col_index, value)
        end
      end

      def auto_size_columns(worksheet, column_count)
        # Basic implementation - rubyXL doesn't have auto-sizing
        # Column width is set to a reasonable default
      end

      # Reuse methods from CSV exporter
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
          response.merge(phrases_found: response_phrases.join(", "))
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
        entities.map { |e| "#{e[:text]}:#{e[:type]}" }.join(", ")
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
        distribution.map { |sentiment, count| "#{sentiment}:#{count}" }.join(", ")
      end

      def format_segment_distribution(distribution)
        parts = []
        distribution.each do |segment_type, values|
          values.each do |value, count|
            parts << "#{segment_type}_#{value}:#{count}"
          end
        end
        parts.join(", ")
      end

      # Override build_base_row for entities and key phrases
      def build_base_row(response, index)
        response_id = response[:id] || "r_#{index + 1}"
        text = response[:sentence] || response[:answer] || ""

        case analysis_type
        when :sentiment
          sentiment_label = response[:sentiment_label] || response[:sentiment] || ""
          sentiment_score = response[:sentiment_score] || 0.0
          [response_id, text, sentiment_label, sentiment_score]
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