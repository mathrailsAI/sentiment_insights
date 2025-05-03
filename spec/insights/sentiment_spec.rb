require 'spec_helper'
require 'sentiment_insights/insights/sentiment'

RSpec.describe SentimentInsights::Insights::Sentiment do
  let(:entries) do
    [
      { answer: "Loved the product experience!", segment: { age: "18-25", region: "North" } },
      { answer: "It was terrible and frustrating.", segment: { age: "26-35", region: "South" } },
      { answer: "It was okay.", segment: { age: "18-25", region: "East" } }
    ]
  end

  shared_examples "valid sentiment summary" do
    it "returns properly structured sentiment result" do
      result = subject.analyze(entries, question: "How was your experience?")

      expect(result).to include(
                          :global_summary,
                          :segment_summary,
                          :top_positive_comments,
                          :top_negative_comments,
                          :responses
                        )

      expect(result[:responses].size).to eq(entries.size)
      expect(result[:top_positive_comments]).to be_an(Array)
      expect(result[:top_negative_comments]).to be_an(Array)

      result[:responses].each do |res|
        expect(res).to include(:sentiment_label, :sentiment_score)
      end

      expect(result[:global_summary]).to include(
                                           :total_count,
                                           :positive_count,
                                           :neutral_count,
                                           :negative_count,
                                           :positive_percentage,
                                           :neutral_percentage,
                                           :negative_percentage,
                                           :net_sentiment_score
                                         )

      result[:segment_summary].each do |seg_key, seg_values|
        seg_values.each do |seg_val, stats|
          expect(stats).to include(
                             :total_count,
                             :positive_count,
                             :neutral_count,
                             :negative_count,
                             :positive_percentage,
                             :neutral_percentage,
                             :negative_percentage,
                             :net_sentiment_score
                           )
        end
      end
    end
  end

  describe '#initialize' do
    context 'with default parameters' do
      # Don't use expect to receive since it's difficult to mock properly
      it 'creates an instance with Sentimental client when no provider specified' do
        # Allow the configuration to return nil for provider
        allow(SentimentInsights).to receive_message_chain(:configuration, :provider).and_return(nil)

        sentiment = described_class.new
        expect(sentiment.instance_variable_get(:@provider_client))
          .to be_a(SentimentInsights::Clients::Sentiment::SentimentalClient)
      end

      it 'uses default top count' do
        sentiment = described_class.new(provider_client: double('provider_client'))
        expect(sentiment.instance_variable_get(:@top_count))
          .to eq(described_class::DEFAULT_TOP_COUNT)
      end
    end

    context 'with configuration provider' do
      before do
        # Stub the configuration
        allow(SentimentInsights).to receive_message_chain(:configuration, :provider).and_return(:openai)
        # Stub client creation to prevent API calls
        allow(SentimentInsights::Clients::Sentiment::OpenAIClient).to receive(:new).and_return(double('openai_client'))
      end

      it 'respects the configured provider' do
        sentiment = described_class.new
        # Just check the class was created, not that it's a specific instance
        expect(SentimentInsights::Clients::Sentiment::OpenAIClient).to have_received(:new)
      end
    end

    context 'with custom provider' do
      before do
        # Stub client creations
        allow(SentimentInsights::Clients::Sentiment::OpenAIClient).to receive(:new).and_return(double('openai_client'))
        allow(SentimentInsights::Clients::Sentiment::AwsComprehendClient).to receive(:new).and_return(double('aws_client'))
      end

      it 'creates instance with OpenAI client' do
        sentiment = described_class.new(provider: :openai)
        expect(SentimentInsights::Clients::Sentiment::OpenAIClient).to have_received(:new)
      end

      it 'creates instance with AWS Comprehend client' do
        sentiment = described_class.new(provider: :aws)
        expect(SentimentInsights::Clients::Sentiment::AwsComprehendClient).to have_received(:new)
      end
    end

    context 'with custom top_count' do
      it 'uses provided top count' do
        custom_top_count = 10
        sentiment = described_class.new(provider_client: double('provider_client'), top_count: custom_top_count)
        expect(sentiment.instance_variable_get(:@top_count)).to eq(custom_top_count)
      end
    end
  end

  context 'with Sentimental provider' do
    before do
      # Mock the SentimentalClient to avoid actual processing
      sentimental_client = double('sentimental_client')
      allow(sentimental_client).to receive(:analyze_entries).and_return(
        entries.map { |e| { label: :positive, score: 0.8 } }
      )
      allow(SentimentInsights::Clients::Sentiment::SentimentalClient).to receive(:new).and_return(sentimental_client)
    end

    subject { described_class.new(provider: :sentimental) }
    include_examples "valid sentiment summary"
  end

  context 'with mocked OpenAI provider' do
    let(:mock_client) do
      double('mock_openai_client').tap do |client|
        allow(client).to receive(:analyze_entries) do |entries, question: nil|
          entries.map.with_index do |_, i|
            { label: [:positive, :negative, :neutral][i % 3], score: [0.9, -0.8, 0.1][i % 3] }
          end
        end
      end
    end

    subject { described_class.new(provider_client: mock_client) }
    include_examples "valid sentiment summary"

    describe 'global summary calculations' do
      it 'calculates correct sentiment counts and percentages' do
        result = subject.analyze(entries)
        global_summary = result[:global_summary]

        # With 3 entries and our mock responses, we should have 1 of each sentiment
        expect(global_summary[:total_count]).to eq(3)
        expect(global_summary[:positive_count]).to eq(1)
        expect(global_summary[:negative_count]).to eq(1)
        expect(global_summary[:neutral_count]).to eq(1)

        # Each should be 33.33%
        expect(global_summary[:positive_percentage]).to be_within(0.01).of(33.33)
        expect(global_summary[:negative_percentage]).to be_within(0.01).of(33.33)
        expect(global_summary[:neutral_percentage]).to be_within(0.01).of(33.33)

        # Net sentiment should be 0 (positive% - negative%)
        expect(global_summary[:net_sentiment_score]).to be_within(0.01).of(0.0)
      end
    end

    describe 'segment summary calculations' do
      it 'calculates correct segment-based statistics' do
        result = subject.analyze(entries)
        segment_summary = result[:segment_summary]

        # Check age segment statistics
        expect(segment_summary).to have_key(:age)
        age_summary = segment_summary[:age]
        expect(age_summary.keys).to match_array(["18-25", "26-35"])

        # The 18-25 segment should have 2 entries with our mock data:
        # First entry: positive, Third entry: neutral
        young_segment = age_summary["18-25"]
        expect(young_segment[:total_count]).to eq(2)
        expect(young_segment[:positive_count]).to eq(1)
        expect(young_segment[:neutral_count]).to eq(1)
        expect(young_segment[:negative_count]).to eq(0)

        # Percentages for 18-25 age group
        expect(young_segment[:positive_percentage]).to be_within(0.01).of(50.0)
        expect(young_segment[:neutral_percentage]).to be_within(0.01).of(50.0)
        expect(young_segment[:negative_percentage]).to be_within(0.01).of(0.0)
        expect(young_segment[:net_sentiment_score]).to be_within(0.01).of(50.0)
      end
    end

    describe 'top comments selection' do
      it 'returns top comments sorted by sentiment score' do
        result = subject.analyze(entries)

        # With our mock setup, entry 0 is positive with score 0.9
        expect(result[:top_positive_comments].first[:answer]).to eq("Loved the product experience!")
        expect(result[:top_positive_comments].first[:score]).to eq(0.9)

        # Entry 1 is negative with score -0.8
        expect(result[:top_negative_comments].first[:answer]).to eq("It was terrible and frustrating.")
        expect(result[:top_negative_comments].first[:score]).to eq(-0.8)
      end

      it 'respects custom top_count parameter' do
        # Create a client that returns more entries
        custom_entries = entries + [
          { answer: "Another positive comment", segment: { age: "18-25" } },
          { answer: "Another negative comment", segment: { age: "26-35" } }
        ]

        custom_mock_client = double('custom_mock_client')
        allow(custom_mock_client).to receive(:analyze_entries) do |entries, question: nil|
          entries.map.with_index do |_, i|
            sentiment_type = i % 3 == 0 ? :positive : (i % 3 == 1 ? :negative : :neutral)
            score = sentiment_type == :positive ? 0.9 - (i * 0.1) :
                      (sentiment_type == :negative ? -0.8 - (i * 0.1) : 0.1)
            { label: sentiment_type, score: score }
          end
        end

        sentiment = described_class.new(provider_client: custom_mock_client, top_count: 2)
        result = sentiment.analyze(custom_entries)

        # Should have 2 positive comments due to top_count
        expect(result[:top_positive_comments].size).to eq(2)
        # Should have 2 negative comments due to top_count
        expect(result[:top_negative_comments].size).to eq(2)

        # They should be sorted by score - positive comments in descending order
        expect(result[:top_positive_comments][0][:score]).to be > result[:top_positive_comments][1][:score]
        # Negative comments in ascending order (most negative first)
        expect(result[:top_negative_comments][0][:score]).to be < result[:top_negative_comments][1][:score]
      end
    end
  end

  context 'with mocked AWS provider' do
    let(:mock_client) do
      double('mock_aws_client').tap do |client|
        allow(client).to receive(:analyze_entries) do |entries, question: nil|
          entries.map { { label: :positive, score: 0.9 } }
        end
      end
    end

    subject { described_class.new(provider_client: mock_client) }
    include_examples "valid sentiment summary"

    it 'handles uniformly positive sentiment correctly' do
      result = subject.analyze(entries)

      expect(result[:global_summary][:positive_count]).to eq(3)
      expect(result[:global_summary][:negative_count]).to eq(0)
      expect(result[:global_summary][:neutral_count]).to eq(0)
      expect(result[:global_summary][:positive_percentage]).to eq(100.0)
      expect(result[:global_summary][:net_sentiment_score]).to eq(100.0)
    end
  end

  context 'with empty entries' do
    let(:empty_entries) { [] }

    let(:mock_client) do
      double('mock_client').tap do |client|
        allow(client).to receive(:analyze_entries).and_return([])
      end
    end

    subject { described_class.new(provider_client: mock_client) }

    it 'handles empty entries properly' do
      result = subject.analyze(empty_entries)

      expect(result[:global_summary][:total_count]).to eq(0)
      expect(result[:global_summary][:positive_count]).to eq(0)
      expect(result[:global_summary][:negative_count]).to eq(0)
      expect(result[:global_summary][:neutral_count]).to eq(0)
      expect(result[:global_summary][:positive_percentage]).to eq(0.0)
      expect(result[:global_summary][:negative_percentage]).to eq(0.0)
      expect(result[:global_summary][:neutral_percentage]).to eq(0.0)
      expect(result[:global_summary][:net_sentiment_score]).to eq(0.0)

      expect(result[:segment_summary]).to eq({})
      expect(result[:top_positive_comments]).to eq([])
      expect(result[:top_negative_comments]).to eq([])
      expect(result[:responses]).to eq([])
    end
  end

  context 'with missing segment data' do
    let(:entries_without_segments) do
      [
        { answer: "Loved the product experience!" },
        { answer: "It was terrible and frustrating." }
      ]
    end

    let(:mock_client) do
      double('mock_client').tap do |client|
        allow(client).to receive(:analyze_entries) do |entries, question: nil|
          entries.map.with_index do |_, i|
            { label: i == 0 ? :positive : :negative, score: i == 0 ? 0.9 : -0.8 }
          end
        end
      end
    end

    subject { described_class.new(provider_client: mock_client) }

    it 'handles entries without segment data' do
      result = subject.analyze(entries_without_segments)

      expect(result[:global_summary][:total_count]).to eq(2)
      expect(result[:segment_summary]).to eq({})

      # Check that responses still have empty segment hashes
      result[:responses].each do |res|
        expect(res[:segment]).to eq({})
      end
    end
  end

  context 'with missing provider results' do
    let(:mock_client_with_missing_results) do
      double('mock_client_missing_results').tap do |client|
        allow(client).to receive(:analyze_entries) do |entries, question: nil|
          # Return fewer results than entries
          [{ label: :positive, score: 0.9 }]
        end
      end
    end

    subject { described_class.new(provider_client: mock_client_with_missing_results) }

    it 'handles missing provider results gracefully' do
      result = subject.analyze(entries)

      expect(result[:responses].size).to eq(3)
      expect(result[:responses][0][:sentiment_label]).to eq(:positive)
      expect(result[:responses][0][:sentiment_score]).to eq(0.9)

      # Check other responses have nil sentiment values
      expect(result[:responses][1][:sentiment_label]).to be_nil
      expect(result[:responses][1][:sentiment_score]).to be_nil
      expect(result[:responses][2][:sentiment_label]).to be_nil
      expect(result[:responses][2][:sentiment_score]).to be_nil
    end
  end
end