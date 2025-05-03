require 'spec_helper'
require 'sentiment_insights/insights/entities'

RSpec.describe SentimentInsights::Insights::Entities do
  let(:entries) do
    [
      {
        answer: "Apple released a new iPhone in San Francisco last week.",
        segment: { age: "18-25", region: "West" }
      },
      {
        answer: "Microsoft Teams was down during our Zoom meeting yesterday.",
        segment: { age: "26-35", region: "East" }
      },
      {
        answer: "The Google Cloud Platform outage affected Netflix streaming.",
        segment: { age: "18-25", region: "Central" }
      }
    ]
  end

  shared_examples "valid entity extraction" do
    it "returns properly structured extraction result" do
      result = subject.extract(entries, question: "What technical issues did you experience?")

      # Check the main structure
      expect(result).to include(:entities, :responses)
      expect(result[:entities]).to be_an(Array)
      expect(result[:responses]).to be_an(Array)

      # Check responses structure
      if result[:responses].any?
        result[:responses].each do |resp|
          expect(resp).to include(:id)
          expect(resp[:id]).to be_a(String)
        end
      end

      # Check entities structure
      if result[:entities].any?
        result[:entities].each do |entity|
          expect(entity).to include(:entity, :type, :mentions, :summary)
          expect(entity[:mentions]).to be_an(Array)

          summary = entity[:summary]
          expect(summary).to include(:total_mentions, :segment_distribution)

          # Verify segment distribution if we have segments
          if summary[:segment_distribution].any?
            summary[:segment_distribution].each do |segment_key, segment_values|
              expect(segment_values).to be_a(Hash)
            end
          end
        end
      end
    end
  end

  describe '#initialize' do
    # Set up module namespaces to avoid "uninitialized constant" errors
    before(:all) do
      module SentimentInsights
        module Clients
          module Entities
            class OpenAIClient; end
            class AwsClient; end
          end
        end
      end
    end

    context 'with default parameters' do
      before do
        # Stub the configuration
        allow(SentimentInsights).to receive_message_chain(:configuration, :provider).and_return(nil)
      end

      it 'raises NotImplementedError with Sentimental provider' do
        expect { described_class.new }.to raise_error(NotImplementedError, /not supported/)
      end
    end

    context 'with configuration provider' do
      before do
        # Stub the configuration
        allow(SentimentInsights).to receive_message_chain(:configuration, :provider).and_return(:openai)

        # Stub require_relative to avoid loading actual files
        allow_any_instance_of(Object).to receive(:require_relative).and_return(true)

        # Stub client creation to prevent API calls
        allow(SentimentInsights::Clients::Entities::OpenAIClient).to receive(:new).and_return(double('openai_client'))
      end

      it 'uses the configured provider' do
        expect(SentimentInsights::Clients::Entities::OpenAIClient).to receive(:new)
        described_class.new
      end
    end

    context 'with custom provider' do
      before do
        # Stub require_relative to avoid loading actual files
        allow_any_instance_of(Object).to receive(:require_relative).and_return(true)

        # Stub client creations
        allow(SentimentInsights::Clients::Entities::OpenAIClient).to receive(:new).and_return(double('openai_client'))
        allow(SentimentInsights::Clients::Entities::AwsClient).to receive(:new).and_return(double('aws_client'))
      end

      it 'creates instance with OpenAI client' do
        expect(SentimentInsights::Clients::Entities::OpenAIClient).to receive(:new)
        described_class.new(provider: :openai)
      end

      it 'creates instance with AWS client' do
        expect(SentimentInsights::Clients::Entities::AwsClient).to receive(:new)
        described_class.new(provider: :aws)
      end

      it 'raises error for unsupported provider' do
        expect { described_class.new(provider: :unsupported) }
          .to raise_error(ArgumentError, /Unsupported provider/)
      end

      it 'raises error for sentimental provider' do
        expect { described_class.new(provider: :sentimental) }
          .to raise_error(NotImplementedError, /not supported/)
      end
    end
  end

  context 'with mocked OpenAI provider' do
    let(:mock_client) do
      double('mock_openai_client').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                segment: entries[0][:segment]
              },
              {
                id: "r_2",
                sentence: entries[1][:answer],
                segment: entries[1][:segment]
              },
              {
                id: "r_3",
                sentence: entries[2][:answer],
                segment: entries[2][:segment]
              }
            ],
            entities: [
              {
                entity: "Apple",
                type: "ORGANIZATION",
                mentions: ["r_1"]
              },
              {
                entity: "iPhone",
                type: "PRODUCT",
                mentions: ["r_1"]
              },
              {
                entity: "San Francisco",
                type: "LOCATION",
                mentions: ["r_1"]
              },
              {
                entity: "Microsoft Teams",
                type: "PRODUCT",
                mentions: ["r_2"]
              },
              {
                entity: "Zoom",
                type: "PRODUCT",
                mentions: ["r_2"]
              },
              {
                entity: "Google Cloud Platform",
                type: "SERVICE",
                mentions: ["r_3"]
              },
              {
                entity: "Netflix",
                type: "ORGANIZATION",
                mentions: ["r_3"]
              }
            ]
          }
        end
      end
    end

    subject { described_class.new(provider_client: mock_client) }
    include_examples "valid entity extraction"

    describe 'entity enrichment' do
      it 'properly enriches entities with segment data' do
        # Stub the puts call to avoid noise in test output
        allow_any_instance_of(described_class).to receive(:puts)

        result = subject.extract(entries)

        # Find the Apple entity
        apple_entity = result[:entities].find { |e| e[:entity] == "Apple" }
        expect(apple_entity).not_to be_nil

        # It should have 1 mention
        expect(apple_entity[:mentions].size).to eq(1)
        expect(apple_entity[:summary][:total_mentions]).to eq(1)

        # Check segment distribution (appears in 18-25 age group and West region)
        segment_dist = apple_entity[:summary][:segment_distribution]
        expect(segment_dist[:age]["18-25"]).to eq(1)
        expect(segment_dist[:region]["West"]).to eq(1)

        # Find Netflix entity
        netflix_entity = result[:entities].find { |e| e[:entity] == "Netflix" }
        expect(netflix_entity).not_to be_nil

        # Check segment distribution (appears in 18-25 age group and Central region)
        segment_dist = netflix_entity[:summary][:segment_distribution]
        expect(segment_dist[:age]["18-25"]).to eq(1)
        expect(segment_dist[:region]["Central"]).to eq(1)
      end

      it 'handles entities that appear in multiple responses' do
        # Stub the puts call to avoid noise in test output
        allow_any_instance_of(described_class).to receive(:puts)

        # Modify the mock to have an entity appearing in multiple responses
        allow(mock_client).to receive(:extract_batch) do |entries, question: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                segment: entries[0][:segment]
              },
              {
                id: "r_2",
                sentence: entries[1][:answer],
                segment: entries[1][:segment]
              },
              {
                id: "r_3",
                sentence: entries[2][:answer],
                segment: entries[2][:segment]
              }
            ],
            entities: [
              {
                entity: "Tech Company",
                type: "ORGANIZATION",
                mentions: %w[r_1 r_2 r_3] # Appears in all responses
              }
            ]
          }
        end

        result = subject.extract(entries)

        # Find the Tech Company entity
        tech_company_entity = result[:entities].find { |e| e[:entity] == "Tech Company" }
        expect(tech_company_entity).not_to be_nil

        # It should have 3 mentions
        expect(tech_company_entity[:mentions].size).to eq(3)
        expect(tech_company_entity[:summary][:total_mentions]).to eq(3)

        # Check segment distribution (appears in all age groups and regions)
        segment_dist = tech_company_entity[:summary][:segment_distribution]
        expect(segment_dist[:age]["18-25"]).to eq(2)  # Two responses in this age group
        expect(segment_dist[:age]["26-35"]).to eq(1)  # One response in this age group

        expect(segment_dist[:region]["West"]).to eq(1)
        expect(segment_dist[:region]["East"]).to eq(1)
        expect(segment_dist[:region]["Central"]).to eq(1)
      end
    end
  end

  context 'with mocked AWS provider' do
    let(:mock_client) do
      double('mock_aws_client').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                segment: entries[0][:segment]
              }
            ],
            entities: [
              {
                entity: "Apple",
                type: "COMMERCIAL_ITEM",
                mentions: ["r_1"]
              }
            ]
          }
        end
      end
    end

    subject { described_class.new(provider_client: mock_client) }

    # Suppress puts statements
    before do
      allow_any_instance_of(described_class).to receive(:puts)
    end

    include_examples "valid entity extraction"
  end

  context 'with empty entries' do
    let(:empty_entries) { [] }

    let(:mock_client) do
      double('mock_client').tap do |client|
        allow(client).to receive(:extract_batch).and_return({
                                                              responses: [],
                                                              entities: []
                                                            })
      end
    end

    subject { described_class.new(provider_client: mock_client) }

    before do
      allow_any_instance_of(described_class).to receive(:puts)
    end

    it 'handles empty entries properly' do
      result = subject.extract(empty_entries)

      expect(result[:entities]).to eq([])
      expect(result[:responses]).to eq([])
    end
  end

  context 'with missing segment data' do
    let(:entries_without_segments) do
      [
        { answer: "Apple released a new iPhone in San Francisco last week." },
        { answer: "Microsoft Teams was down during our Zoom meeting yesterday." }
      ]
    end

    let(:mock_client) do
      double('mock_client').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer]
                # No segment data
              },
              {
                id: "r_2",
                sentence: entries[1][:answer]
                # No segment data
              }
            ],
            entities: [
              {
                entity: "Apple",
                type: "ORGANIZATION",
                mentions: ["r_1"]
              },
              {
                entity: "Microsoft Teams",
                type: "PRODUCT",
                mentions: ["r_2"]
              }
            ]
          }
        end
      end
    end

    subject { described_class.new(provider_client: mock_client) }

    before do
      allow_any_instance_of(described_class).to receive(:puts)
    end

    it 'handles entries without segment data' do
      result = subject.extract(entries_without_segments)

      # Entities should still be processed
      expect(result[:entities].size).to eq(2)

      # Segment distribution should be empty for Apple
      apple_entity = result[:entities].find { |e| e[:entity] == "Apple" }
      expect(apple_entity[:summary][:segment_distribution]).to eq({})
    end
  end

  context 'with provider returning incomplete data' do
    let(:mock_client_with_incomplete_data) do
      double('mock_client_incomplete').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil|
          {
            # Missing responses but has entities
            entities: [
              {
                entity: "Apple",
                type: "ORGANIZATION",
                mentions: ["r_1"]
              }
            ]
          }
        end
      end
    end

    subject { described_class.new(provider_client: mock_client_with_incomplete_data) }

    before do
      allow_any_instance_of(described_class).to receive(:puts)
    end

    it 'handles missing responses data gracefully' do
      result = subject.extract(entries)

      expect(result[:entities]).to be_an(Array)
      expect(result[:responses]).to eq([])

      # Should handle the missing response references
      apple_entity = result[:entities].first
      expect(apple_entity[:summary][:total_mentions]).to eq(1)
      expect(apple_entity[:summary][:segment_distribution]).to eq({})
    end
  end

  context 'with provider returning null mention ids' do
    let(:mock_client_with_null_mentions) do
      double('mock_client_null_mentions').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                segment: entries[0][:segment]
              }
            ],
            entities: [
              {
                entity: "Apple",
                type: "ORGANIZATION",
                mentions: nil  # Null mentions
              }
            ]
          }
        end
      end
    end

    subject { described_class.new(provider_client: mock_client_with_null_mentions) }

    before do
      allow_any_instance_of(described_class).to receive(:puts)
    end

    it 'handles null mentions gracefully' do
      result = subject.extract(entries)

      apple_entity = result[:entities].first
      expect(apple_entity[:mentions]).to eq([])
      expect(apple_entity[:summary][:total_mentions]).to eq(0)
    end
  end

  context 'with invalid response IDs in mentions' do
    let(:mock_client_with_invalid_ids) do
      double('mock_client_invalid_ids').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                segment: entries[0][:segment]
              }
            ],
            entities: [
              {
                entity: "Apple",
                type: "ORGANIZATION",
                mentions: %w[r_1 r_nonexistent] # Second, ID doesn't exist
              }
            ]
          }
        end
      end
    end

    subject { described_class.new(provider_client: mock_client_with_invalid_ids) }

    before do
      allow_any_instance_of(described_class).to receive(:puts)
    end

    it 'handles invalid response IDs gracefully' do
      result = subject.extract(entries)

      apple_entity = result[:entities].first
      # Mentions array should still have both IDs
      expect(apple_entity[:mentions]).to eq(%w[r_1 r_nonexistent])
      # But only valid ones should be counted in segment distribution
      expect(apple_entity[:summary][:segment_distribution][:age]["18-25"]).to eq(1)
    end
  end

  context 'with entities having empty fields' do
    let(:mock_client_with_empty_fields) do
      double('mock_client_empty_fields').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                segment: entries[0][:segment]
              }
            ],
            entities: [
              {
                entity: "",  # Empty entity name
                type: "ORGANIZATION",
                mentions: ["r_1"]
              },
              {
                # Missing entity field
                type: "PRODUCT",
                mentions: ["r_1"]
              },
              {
                entity: "Microsoft",
                # Missing type field
                mentions: ["r_1"]
              }
            ]
          }
        end
      end
    end

    subject { described_class.new(provider_client: mock_client_with_empty_fields) }

    before do
      allow_any_instance_of(described_class).to receive(:puts)
    end

    it 'handles entities with empty or missing fields' do
      # This test verifies the code doesn't break with malformed entity data
      result = subject.extract(entries)

      # All three entities should still be processed
      expect(result[:entities].size).to eq(3)
    end
  end
end