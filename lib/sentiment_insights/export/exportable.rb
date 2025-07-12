require_relative 'exporter'

module SentimentInsights
  module Export
    # Module to be extended on result hashes to add export functionality
    module Exportable
      # Export to CSV format
      # @param filename [String, nil] Optional filename. If nil, auto-generates timestamp-based name
      # @param options [Hash] Export options
      # @return [String] Path to exported file
      def to_csv(filename = nil, options = {})
        merged_options = (@export_options || {}).merge(options)
        exporter = SentimentInsights::Export::Exporter.new(self, merged_options)
        exporter.to_csv(filename)
      end

      # Export to Excel format
      # @param filename [String, nil] Optional filename. If nil, auto-generates timestamp-based name  
      # @param options [Hash] Export options
      # @return [String] Path to exported file
      def to_excel(filename = nil, options = {})
        merged_options = (@export_options || {}).merge(options)
        exporter = SentimentInsights::Export::Exporter.new(self, merged_options)
        exporter.to_excel(filename)
      end

      # Export to JSON format
      # @param filename [String, nil] Optional filename. If nil, auto-generates timestamp-based name
      # @param options [Hash] Export options
      # @return [String] Path to exported file
      def to_json(filename = nil, options = {})
        merged_options = (@export_options || {}).merge(options)
        exporter = SentimentInsights::Export::Exporter.new(self, merged_options)
        exporter.to_json(filename)
      end

      # Return JSON as string (for API responses)
      # @param options [Hash] Export options
      # @return [String] JSON string
      def to_json_string(options = {})
        merged_options = (@export_options || {}).merge(options)
        exporter = SentimentInsights::Export::Exporter.new(self, merged_options)
        exporter.to_json_string
      end

      # Return as hash structure (for API responses)
      # @param options [Hash] Export options
      # @return [Hash] Structured data hash
      def to_hash(options = {})
        merged_options = (@export_options || {}).merge(options)
        exporter = SentimentInsights::Export::Exporter.new(self, merged_options)
        exporter.to_hash
      end

      # Export to specified format (auto-detects from filename extension)
      # @param filename_or_format [String, Symbol] Filename with extension or format symbol (:csv, :excel)
      # @param options [Hash] Export options
      # @return [String] Path to exported file
      def export(filename_or_format = nil, options = {})
        merged_options = (@export_options || {}).merge(options)
        exporter = SentimentInsights::Export::Exporter.new(self, merged_options)
        exporter.export(filename_or_format)
      end

      # Create an exporter instance for advanced operations
      # @param options [Hash] Export options
      # @return [SentimentInsights::Export::Exporter] Exporter instance
      def exporter(options = {})
        merged_options = (@export_options || {}).merge(options)
        SentimentInsights::Export::Exporter.new(self, merged_options)
      end

      # Quick export methods with common filters
      
      # Export only positive responses
      def export_positive(format = :csv, filename = nil)
        exporter.positive_only(format, filename)
      end

      # Export only negative responses  
      def export_negative(format = :csv, filename = nil)
        exporter.negative_only(format, filename)
      end

      # Export responses from specific segments
      def export_by_segment(segment_type, segment_values, format = :csv, filename = nil)
        exporter.by_segment(segment_type, segment_values, format, filename)
      end

      # Export to both CSV and Excel formats
      def export_all(base_filename = nil)
        exporter.export_all(base_filename)
      end

      # Configuration methods for fluent interface
      
      # Configure export with options and return self for chaining
      def with_export_options(options)
        @export_options = (@export_options || {}).merge(options)
        self
      end

      # Export only summary data (no individual responses)
      def summary_only
        with_export_options(include_segments: false, summary_only: true)
      end

      # Export only response data (no summary/segments)
      def responses_only
        with_export_options(include_summary: false, include_segments: false)
      end

      # Include detailed segment analysis
      def with_segments
        with_export_options(include_segments: true)
      end

      # Exclude segment analysis
      def without_segments
        with_export_options(include_segments: false)
      end

      # Filter by sentiment
      def filter_sentiment(*sentiments)
        with_export_options(filter: { sentiment: sentiments.flatten })
      end

      # Filter by segment criteria
      def filter_segments(segment_filters)
        current_filter = @export_options&.dig(:filter) || {}
        new_filter = current_filter.merge(segments: segment_filters)
        with_export_options(filter: new_filter)
      end

    end

    # Result class that wraps analysis results with export functionality
    class Result < Hash
      include Exportable

      def initialize(data = {})
        super()
        merge!(data)
      end

      # Factory method to create Result from analysis output
      def self.wrap(analysis_result)
        new(analysis_result)
      end
    end
  end
end