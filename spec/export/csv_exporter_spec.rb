require 'spec_helper'
require 'sentiment_insights/export/csv_exporter'
require 'csv'
require 'tempfile'

RSpec.describe SentimentInsights::Export::CsvExporter do
  let(:sentiment_result) do
    {
      global_summary: {
        total_count: 3,
        positive_count: 2,
        neutral_count: 0,
        negative_count: 1,
        positive_percentage: 66.7,
        neutral_percentage: 0.0,
        negative_percentage: 33.3,
        net_sentiment_score: 33.4
      },
      segment_summary: {
        age_group: {
          "18-25" => {
            total_count: 2,
            positive_count: 1,
            neutral_count: 0,
            negative_count: 1,
            positive_percentage: 50.0,
            neutral_percentage: 0.0,
            negative_percentage: 50.0,
            net_sentiment_score: 0.0
          },
          "26-35" => {
            total_count: 1,
            positive_count: 1,
            neutral_count: 0,
            negative_count: 0,
            positive_percentage: 100.0,
            neutral_percentage: 0.0,
            negative_percentage: 0.0,
            net_sentiment_score: 100.0
          }
        }
      },
      responses: [
        {
          answer: "I love this product!",
          segment: { age_group: "18-25", region: "North" },
          sentiment_label: :positive,
          sentiment_score: 0.9
        },
        {
          answer: "This is terrible.",
          segment: { age_group: "18-25", region: "South" },
          sentiment_label: :negative,
          sentiment_score: -0.8
        },
        {
          answer: "Great experience overall.",
          segment: { age_group: "26-35", region: "West" },
          sentiment_label: :positive,
          sentiment_score: 0.7
        }
      ]
    }
  end

  let(:entities_result) do
    {
      entities: [
        {
          entity: "apple",
          type: "ORGANIZATION",
          mentions: ["r_1", "r_2"],
          summary: {
            total_mentions: 2,
            segment_distribution: {
              age_group: { "18-25" => 1, "26-35" => 1 },
              region: { "North" => 1, "West" => 1 }
            }
          }
        },
        {
          entity: "iphone",
          type: "PRODUCT",
          mentions: ["r_1"],
          summary: {
            total_mentions: 1,
            segment_distribution: {
              age_group: { "18-25" => 1 },
              region: { "North" => 1 }
            }
          }
        }
      ],
      responses: [
        {
          id: "r_1",
          sentence: "Apple released a new iPhone.",
          segment: { age_group: "18-25", region: "North" }
        },
        {
          id: "r_2", 
          sentence: "Apple products are great.",
          segment: { age_group: "26-35", region: "West" }
        }
      ]
    }
  end

  describe '#export' do
    context 'with sentiment analysis results' do
      let(:exporter) { described_class.new(sentiment_result) }

      it 'creates a CSV file with proper headers' do
        tempfile = Tempfile.new(['sentiment_test', '.csv'])
        filename = exporter.export(tempfile.path)

        expect(File.exist?(filename)).to be true
        
        csv_content = CSV.read(filename, headers: true)
        headers = csv_content.headers
        
        expect(headers).to include('response_id', 'text', 'sentiment_label', 'sentiment_score')
        expect(headers).to include('segment_age_group', 'segment_region')
        expect(headers).to include('timestamp')
        
        tempfile.unlink
      end

      it 'exports response data correctly' do
        tempfile = Tempfile.new(['sentiment_test', '.csv'])
        filename = exporter.export(tempfile.path)

        csv_content = CSV.read(filename, headers: true)
        
        expect(csv_content.length).to be >= 3  # At least 3 data rows
        
        first_row = csv_content[0]
        expect(first_row['text']).to eq("I love this product!")
        expect(first_row['sentiment_label']).to eq("positive")
        expect(first_row['sentiment_score']).to eq("0.9")
        expect(first_row['segment_age_group']).to eq("18-25")
        expect(first_row['segment_region']).to eq("North")
        
        tempfile.unlink
      end

      it 'includes summary statistics when enabled' do
        tempfile = Tempfile.new(['sentiment_test', '.csv'])
        filename = exporter.export(tempfile.path)

        content = File.read(filename)
        
        expect(content).to include('SUMMARY STATISTICS')
        expect(content).to include('Total Responses,3')
        expect(content).to include('Positive Count,2')
        expect(content).to include('Net Sentiment Score,33.4')
        
        tempfile.unlink
      end

      it 'includes segment analysis when enabled' do
        tempfile = Tempfile.new(['sentiment_test', '.csv'])
        filename = exporter.export(tempfile.path)

        content = File.read(filename)
        
        expect(content).to include('SEGMENT ANALYSIS')
        expect(content).to include('Age Group,18-25')
        expect(content).to include('Age Group,26-35')
        
        tempfile.unlink
      end
    end

    context 'with entity extraction results' do
      let(:exporter) { described_class.new(entities_result) }

      it 'creates a CSV file with entity-specific headers' do
        tempfile = Tempfile.new(['entities_test', '.csv'])
        filename = exporter.export(tempfile.path)

        expect(File.exist?(filename)).to be true
        
        csv_content = CSV.read(filename, headers: true)
        headers = csv_content.headers
        
        expect(headers).to include('response_id', 'text', 'entities_found')
        expect(headers).to include('segment_age_group', 'segment_region')
        
        tempfile.unlink
      end

      it 'exports entity data correctly' do
        tempfile = Tempfile.new(['entities_test', '.csv'])
        filename = exporter.export(tempfile.path)

        csv_content = CSV.read(filename, headers: true)
        
        expect(csv_content.length).to be >= 2  # At least 2 data rows
        
        first_row = csv_content[0]
        expect(first_row['text']).to eq("Apple released a new iPhone.")
        expect(first_row['segment_age_group']).to eq("18-25")
        expect(first_row['segment_region']).to eq("North")
        
        tempfile.unlink
      end
    end

    context 'with export options' do
      let(:exporter) { described_class.new(sentiment_result, include_summary: false) }

      it 'respects include_summary option' do
        tempfile = Tempfile.new(['no_summary_test', '.csv'])
        filename = exporter.export(tempfile.path)

        content = File.read(filename)
        
        expect(content).not_to include('SUMMARY STATISTICS')
        
        tempfile.unlink
      end
    end

    context 'with filtering options' do
      let(:filter_options) do
        {
          filter: {
            sentiment: [:positive]
          },
          include_summary: false,
          include_segments: false
        }
      end
      let(:exporter) { described_class.new(sentiment_result, filter_options) }

      it 'filters responses by sentiment' do
        tempfile = Tempfile.new(['filtered_test', '.csv'])
        filename = exporter.export(tempfile.path)

        csv_content = CSV.read(filename, headers: true)
        
        # Should only have positive responses
        csv_content.each do |row|
          next if row['sentiment_label'].nil?  # Skip summary rows
          expect(row['sentiment_label']).to eq('positive')
        end
        
        tempfile.unlink
      end
    end

    context 'with dynamic segments' do
      let(:complex_segments_result) do
        {
          responses: [
            {
              answer: "Great product!",
              segment: { 
                demographics: { age: "25-34", income: "high" },
                location: { country: "USA", state: "CA" },
                simple_key: "value1"
              },
              sentiment_label: :positive,
              sentiment_score: 0.8
            },
            {
              answer: "Poor service.",
              segment: {
                demographics: { age: "35-44", income: "medium" },
                location: { country: "Canada", state: "ON" },
                simple_key: "value2"
              },
              sentiment_label: :negative,
              sentiment_score: -0.6
            }
          ]
        }
      end
      
      let(:exporter) { described_class.new(complex_segments_result) }

      it 'handles nested segment structures' do
        tempfile = Tempfile.new(['complex_segments_test', '.csv'])
        filename = exporter.export(tempfile.path)

        csv_content = CSV.read(filename, headers: true)
        headers = csv_content.headers
        
        # Should flatten nested segments
        expect(headers).to include('segment_demographics_age')
        expect(headers).to include('segment_demographics_income')
        expect(headers).to include('segment_location_country')
        expect(headers).to include('segment_location_state')
        expect(headers).to include('segment_simple_key')
        
        # Check data
        first_row = csv_content[0]
        expect(first_row['segment_demographics_age']).to eq("25-34")
        expect(first_row['segment_demographics_income']).to eq("high")
        expect(first_row['segment_location_country']).to eq("USA")
        expect(first_row['segment_location_state']).to eq("CA")
        
        tempfile.unlink
      end
    end
  end

  describe '#generate_filename' do
    let(:exporter) { described_class.new(sentiment_result) }

    it 'generates filename with timestamp' do
      filename = exporter.send(:generate_filename, 'csv')
      
      expect(filename).to match(/sentiment_analysis_\d{8}_\d{6}\.csv/)
    end
  end
end