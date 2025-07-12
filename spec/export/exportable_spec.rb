require 'spec_helper'
require 'sentiment_insights/export/exportable'
require 'tempfile'

RSpec.describe SentimentInsights::Export::Exportable do
  let(:sample_sentiment_data) do
    {
      global_summary: {
        total_count: 2,
        positive_count: 1,
        negative_count: 1,
        positive_percentage: 50.0,
        negative_percentage: 50.0,
        net_sentiment_score: 0.0
      },
      responses: [
        {
          answer: "I love this!",
          segment: { age_group: "18-25" },
          sentiment_label: :positive,
          sentiment_score: 0.8
        },
        {
          answer: "This is bad.",
          segment: { age_group: "26-35" },
          sentiment_label: :negative,
          sentiment_score: -0.6
        }
      ]
    }
  end

  let(:result) { SentimentInsights::Export::Result.wrap(sample_sentiment_data) }

  describe 'Result class' do
    it 'behaves like a hash' do
      expect(result[:global_summary]).to eq(sample_sentiment_data[:global_summary])
      expect(result[:responses]).to eq(sample_sentiment_data[:responses])
      expect(result.keys).to include(:global_summary, :responses)
    end

    it 'includes exportable methods' do
      expect(result).to respond_to(:to_csv)
      expect(result).to respond_to(:to_excel)
      expect(result).to respond_to(:export)
      expect(result).to respond_to(:exporter)
    end
  end

  describe '#to_csv' do
    it 'exports to CSV format' do
      tempfile = Tempfile.new(['test_export', '.csv'])
      filename = result.to_csv(tempfile.path)
      
      expect(File.exist?(filename)).to be true
      expect(filename).to eq(tempfile.path)
      
      content = File.read(filename)
      expect(content).to include('response_id,text,sentiment_label,sentiment_score')
      expect(content).to include('I love this!')
      expect(content).to include('This is bad.')
      
      tempfile.unlink
    end

    it 'auto-generates filename when none provided' do
      filename = result.to_csv
      
      expect(File.exist?(filename)).to be true
      expect(filename).to match(/sentiment_analysis_\d{8}_\d{6}\.csv/)
      
      File.delete(filename) if File.exist?(filename)
    end
  end

  describe '#export' do
    it 'detects format from filename extension' do
      tempfile = Tempfile.new(['test_export', '.csv'])
      filename = result.export(tempfile.path)
      
      expect(File.exist?(filename)).to be true
      content = File.read(filename)
      expect(content).to include('response_id,text,sentiment_label')
      
      tempfile.unlink
    end

    it 'uses format symbol' do
      filename = result.export(:csv)
      
      expect(File.exist?(filename)).to be true
      expect(filename).to end_with('.csv')
      
      File.delete(filename) if File.exist?(filename)
    end

    it 'defaults to CSV when no format specified' do
      filename = result.export
      
      expect(File.exist?(filename)).to be true
      expect(filename).to end_with('.csv')
      
      File.delete(filename) if File.exist?(filename)
    end
  end

  describe 'fluent interface' do
    it 'supports method chaining with options' do
      tempfile = Tempfile.new(['fluent_test', '.csv'])
      
      filename = result
        .responses_only
        .filter_sentiment(:positive)
        .to_csv(tempfile.path)
      
      expect(File.exist?(filename)).to be true
      
      content = File.read(filename)
      expect(content).not_to include('SUMMARY STATISTICS')  # responses_only
      expect(content).to include('I love this!')  # positive filter
      expect(content).not_to include('This is bad.')  # negative filtered out
      
      tempfile.unlink
    end

    it 'supports segment filtering' do
      tempfile = Tempfile.new(['segment_test', '.csv'])
      
      filename = result
        .filter_segments(age_group: ["18-25"])
        .to_csv(tempfile.path)
      
      expect(File.exist?(filename)).to be true
      
      content = File.read(filename)
      expect(content).to include('I love this!')  # 18-25 age group
      expect(content).not_to include('This is bad.')  # 26-35 filtered out
      
      tempfile.unlink
    end
  end

  describe '#exporter' do
    it 'returns an exporter instance' do
      exporter = result.exporter
      expect(exporter).to be_a(SentimentInsights::Export::Exporter)
    end

    it 'supports advanced export methods' do
      exporter = result.exporter
      expect(exporter).to respond_to(:positive_only)
      expect(exporter).to respond_to(:negative_only)
      expect(exporter).to respond_to(:by_segment)
    end
  end

  describe 'quick export methods' do
    it 'exports positive responses only' do
      filename = result.export_positive(:csv)
      
      expect(File.exist?(filename)).to be true
      content = File.read(filename)
      expect(content).to include('I love this!')
      expect(content).not_to include('This is bad.')
      
      File.delete(filename) if File.exist?(filename)
    end

    it 'exports negative responses only' do
      filename = result.export_negative(:csv)
      
      expect(File.exist?(filename)).to be true
      content = File.read(filename)
      expect(content).not_to include('I love this!')
      expect(content).to include('This is bad.')
      
      File.delete(filename) if File.exist?(filename)
    end

    it 'exports by segment' do
      filename = result.export_by_segment(:age_group, "18-25", :csv)
      
      expect(File.exist?(filename)).to be true
      content = File.read(filename)
      expect(content).to include('I love this!')
      expect(content).not_to include('This is bad.')
      
      File.delete(filename) if File.exist?(filename)
    end
  end
end