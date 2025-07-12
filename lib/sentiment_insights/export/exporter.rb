require_relative 'csv_exporter'
require_relative 'excel_exporter'
require_relative 'json_exporter'

module SentimentInsights
  module Export
    class Exporter
      attr_reader :result, :options

      def initialize(result, options = {})
        @result = result
        @options = options
      end

      # Main export method - auto-detects format from filename
      def export(filename_or_format = nil, options = {})
        merged_options = @options.merge(options)
        
        if filename_or_format.nil?
          # Default to CSV with auto-generated filename
          to_csv(nil, merged_options)
        elsif filename_or_format.is_a?(Symbol)
          # Format specified as symbol
          case filename_or_format
          when :csv
            to_csv(nil, merged_options)
          when :excel, :xlsx
            to_excel(nil, merged_options)
          when :json
            to_json(nil, merged_options)
          else
            raise ArgumentError, "Unsupported export format: #{filename_or_format}"
          end
        else
          # Filename specified - detect format from extension
          extension = File.extname(filename_or_format).downcase
          case extension
          when '.csv'
            to_csv(filename_or_format, merged_options)
          when '.xlsx', '.xls'
            to_excel(filename_or_format, merged_options)
          when '.json'
            to_json(filename_or_format, merged_options)
          else
            # Default to CSV if no extension or unknown extension
            csv_filename = filename_or_format.include?('.') ? filename_or_format : "#{filename_or_format}.csv"
            to_csv(csv_filename, merged_options)
          end
        end
      end

      # Specific format methods
      def to_csv(filename = nil, options = {})
        merged_options = @options.merge(options)
        CsvExporter.new(@result, merged_options).export(filename)
      end

      def to_excel(filename = nil, options = {})
        merged_options = @options.merge(options)
        ExcelExporter.new(@result, merged_options).export(filename)
      end

      def to_json(filename = nil, options = {})
        merged_options = @options.merge(options)
        JsonExporter.new(@result, merged_options).export(filename)
      end

      # Return JSON as string (for API responses)
      def to_json_string(options = {})
        merged_options = @options.merge(options)
        JsonExporter.new(@result, merged_options).to_json_string
      end

      # Return as hash (for API responses)
      def to_hash(options = {})
        merged_options = @options.merge(options)
        JsonExporter.new(@result, merged_options).to_hash
      end

      # Convenience methods for common export scenarios
      def to_csv_summary_only(filename = nil)
        to_csv(filename, include_segments: false)
      end

      def to_csv_responses_only(filename = nil)
        to_csv(filename, include_summary: false, include_segments: false)
      end

      def to_excel_detailed(filename = nil)
        to_excel(filename, include_summary: true, include_segments: true)
      end

      # Filtered exports
      def positive_only(format = :csv, filename = nil)
        options = { filter: { sentiment: [:positive] } }
        
        case format
        when :csv
          to_csv(filename, options)
        when :excel, :xlsx
          to_excel(filename, options)
        else
          raise ArgumentError, "Unsupported format: #{format}"
        end
      end

      def negative_only(format = :csv, filename = nil)
        options = { filter: { sentiment: [:negative] } }
        
        case format
        when :csv
          to_csv(filename, options)
        when :excel, :xlsx
          to_excel(filename, options)
        else
          raise ArgumentError, "Unsupported format: #{format}"
        end
      end

      def by_segment(segment_type, segment_values, format = :csv, filename = nil)
        options = { 
          filter: { 
            segments: { segment_type.to_sym => Array(segment_values) } 
          } 
        }
        
        case format
        when :csv
          to_csv(filename, options)
        when :excel, :xlsx
          to_excel(filename, options)
        else
          raise ArgumentError, "Unsupported format: #{format}"
        end
      end

      # Batch export - multiple formats at once
      def export_all(base_filename = nil)
        base_name = base_filename || detect_base_filename
        
        files = {}
        files[:csv] = to_csv("#{base_name}.csv")
        
        begin
          files[:excel] = to_excel("#{base_name}.xlsx")
        rescue => e
          puts "Warning: Excel export failed: #{e.message}"
        end
        
        files
      end

      private

      def detect_base_filename
        analysis_type = detect_analysis_type(@result)
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        "#{analysis_type}_analysis_#{timestamp}"
      end

      def detect_analysis_type(result)
        return :sentiment if result.key?(:global_summary) || result.key?(:responses)
        return :entities if result.key?(:entities)
        return :key_phrases if result.key?(:phrases)
        :unknown
      end
    end
  end
end