require 'spec_helper'
require 'sentiment_insights/insights/key_phrases'

RSpec.describe SentimentInsights::Insights::KeyPhrases do
  let(:entries) do
    [
      { 
        answer: "I absolutely loved the checkout experience with Shopify. The interface is clean.", 
        segment: { age: "18-25", region: "North" } 
      },
      { 
        answer: "The product quality was terrible and the delivery was late.", 
        segment: { age: "26-35", region: "South" } 
      },
      { 
        answer: "Customer service team was responsive, but interface was confusing.", 
        segment: { age: "18-25", region: "East" } 
      }
    ]
  end

  shared_examples "valid key phrases extraction" do
    it "returns properly structured extraction result" do
      result = subject.extract(entries, question: "How was your experience?")

      # Check the main structure
      expect(result).to include(:phrases, :responses)
      expect(result[:phrases]).to be_an(Array)
      expect(result[:responses]).to be_an(Array)
      
      # Check responses
      expect(result[:responses].size).to be >= 1
      result[:responses].each do |resp|
        expect(resp).to include(:id, :sentence)
        expect(resp[:id]).to be_a(String)
      end
      
      # Check phrases
      if result[:phrases].any?
        result[:phrases].each do |phrase|
          expect(phrase).to include(:phrase, :mentions, :summary)
          expect(phrase[:mentions]).to be_an(Array)
          
          summary = phrase[:summary]
          expect(summary).to include(:total_mentions, :sentiment_distribution, :segment_distribution)
          
          # Check sentiment distribution
          sentiment_dist = summary[:sentiment_distribution]
          expect(sentiment_dist).to include(:positive, :negative, :neutral)
          
          # Check at least one segment distribution exists if we have segments
          if summary[:segment_distribution].any?
            # Validate the structure of segment distribution 
            summary[:segment_distribution].each do |_, segment_values|
              expect(segment_values).to be_a(Hash)
            end
          end
        end
      end
    end
  end

  describe '#initialize' do
    context 'with default parameters' do
      before do
        # Stub the configuration
        allow(SentimentInsights).to receive_message_chain(:configuration, :provider).and_return(nil)
        
        # We need to stub these because initialize will try to create a client
        # However, Sentimental doesn't support key phrases, so we expect an error
      end
      
      it 'raises NotImplementedError with Sentimental provider' do
        expect { described_class.new }.to raise_error(NotImplementedError, /not supported/)
      end
    end

    context 'with configuration provider' do
      before do
        # Stub the configuration
        allow(SentimentInsights).to receive_message_chain(:configuration, :provider).and_return(:openai)
        # Stub client creation to prevent API calls
        allow(SentimentInsights::Clients::KeyPhrases::OpenAIClient).to receive(:new)
          .and_return(double('openai_client'))
      end

      it 'uses the configured provider' do
        expect(SentimentInsights::Clients::KeyPhrases::OpenAIClient).to receive(:new)
        described_class.new
      end
    end

    context 'with custom provider' do
      before do
        # Stub client creations
        allow(SentimentInsights::Clients::KeyPhrases::OpenAIClient).to receive(:new)
          .and_return(double('openai_client'))
        allow(SentimentInsights::Clients::KeyPhrases::AwsClient).to receive(:new)
          .and_return(double('aws_client'))
      end

      it 'creates instance with OpenAI client' do
        expect(SentimentInsights::Clients::KeyPhrases::OpenAIClient).to receive(:new)
        described_class.new(provider: :openai)
      end

      it 'creates instance with AWS client' do
        expect(SentimentInsights::Clients::KeyPhrases::AwsClient).to receive(:new)
        described_class.new(provider: :aws)
      end
      
      it 'raises error for unsupported provider' do
        expect { described_class.new(provider: :unsupported) }
          .to raise_error(ArgumentError, /Unsupported provider/)
      end
    end
  end

  context 'with mocked OpenAI provider' do
    let(:mock_client) do
      double('mock_openai_client').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil, key_phrase_prompt: nil, sentiment_prompt: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                sentiment: :positive,
                segment: entries[0][:segment]
              },
              {
                id: "r_2",
                sentence: entries[1][:answer],
                sentiment: :negative,
                segment: entries[1][:segment]
              },
              {
                id: "r_3",
                sentence: entries[2][:answer],
                sentiment: :neutral,
                segment: entries[2][:segment]
              }
            ],
            phrases: [
              {
                phrase: "checkout experience",
                mentions: ["r_1"]
              },
              {
                phrase: "product quality",
                mentions: ["r_2"]
              },
              {
                phrase: "customer service",
                mentions: ["r_3"]
              },
              {
                phrase: "interface",
                mentions: %w[r_1 r_3]
              }
            ]
          }
        end
      end
    end

    subject { described_class.new(provider_client: mock_client) }
    include_examples "valid key phrases extraction"
    
    describe 'phrase enrichment' do
      it 'properly enriches phrases with sentiment and segment data' do
        result = subject.extract(entries)
        
        # Find the "interface" phrase which appears in two different responses (r_1, r_3)
        interface_phrase = result[:phrases].find { |p| p[:phrase] == "interface" }
        expect(interface_phrase).not_to be_nil
        
        # It should have 2 mentions
        expect(interface_phrase[:mentions].size).to eq(2)
        expect(interface_phrase[:summary][:total_mentions]).to eq(2)
        
        # Check sentiment distribution (one positive from r_1, one neutral from r_3)
        sentiment_dist = interface_phrase[:summary][:sentiment_distribution]
        expect(sentiment_dist[:positive]).to eq(1)
        expect(sentiment_dist[:neutral]).to eq(1)
        expect(sentiment_dist[:negative]).to eq(0)
        
        # Check segment distribution (appears in both 18-25 age groups)
        segment_dist = interface_phrase[:summary][:segment_distribution]
        expect(segment_dist[:age]["18-25"]).to eq(2)
        
        # Check region distribution (appears in North and East)
        expect(segment_dist[:region]["North"]).to eq(1)
        expect(segment_dist[:region]["East"]).to eq(1)
      end
    end
  end

  context 'with mocked AWS provider' do
    let(:mock_client) do
      double('mock_aws_client').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil, key_phrase_prompt: nil, sentiment_prompt: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                sentiment: :positive,
                segment: entries[0][:segment]
              }
            ],
            phrases: [
              {
                phrase: "checkout experience",
                mentions: ["r_1"]
              }
            ]
          }
        end
      end
    end

    subject { described_class.new(provider_client: mock_client) }
    include_examples "valid key phrases extraction"
  end
  
  context 'with empty entries' do
    let(:empty_entries) { [] }
    
    let(:mock_client) do
      double('mock_client').tap do |client|
        allow(client).to receive(:extract_batch).and_return({
          responses: [],
          phrases: []
        })
      end
    end
    
    subject { described_class.new(provider_client: mock_client) }
    
    it 'handles empty entries properly' do
      result = subject.extract(empty_entries)
      
      expect(result[:phrases]).to eq([])
      expect(result[:responses]).to eq([])
    end
  end
  
  context 'with missing segment data' do
    let(:entries_without_segments) do
      [
        { answer: "Loved the checkout experience!" },
        { answer: "The product quality was terrible." }
      ]
    end
    
    let(:mock_client) do
      double('mock_client').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil, key_phrase_prompt: nil, sentiment_prompt: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                sentiment: :positive
              },
              {
                id: "r_2",
                sentence: entries[1][:answer],
                sentiment: :negative
              }
            ],
            phrases: [
              {
                phrase: "checkout experience",
                mentions: ["r_1"]
              },
              {
                phrase: "product quality",
                mentions: ["r_2"]
              }
            ]
          }
        end
      end
    end
    
    subject { described_class.new(provider_client: mock_client) }
    
    it 'handles entries without segment data' do
      result = subject.extract(entries_without_segments)
      
      # Phrases should still be processed
      expect(result[:phrases].size).to eq(2)
      
      # Segment distribution should be empty
      checkout_phrase = result[:phrases].find { |p| p[:phrase] == "checkout experience" }
      expect(checkout_phrase[:summary][:segment_distribution]).to eq({})
    end
  end
  
  context 'with provider returning incomplete data' do
    let(:mock_client_with_incomplete_data) do
      double('mock_client_incomplete').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil, key_phrase_prompt: nil, sentiment_prompt: nil|
          {
            # Missing responses but has phrases
            phrases: [
              {
                phrase: "checkout experience",
                mentions: ["r_1"]
              }
            ]
          }
        end
      end
    end
    
    subject { described_class.new(provider_client: mock_client_with_incomplete_data) }
    
    it 'handles missing responses data gracefully' do
      result = subject.extract(entries)
      
      expect(result[:phrases]).to be_an(Array)
      expect(result[:responses]).to eq([])
      
      # Should handle the missing response references
      checkout_phrase = result[:phrases].first
      expect(checkout_phrase[:summary][:total_mentions]).to eq(1)
      expect(checkout_phrase[:summary][:sentiment_distribution][:positive]).to eq(0)
      expect(checkout_phrase[:summary][:segment_distribution]).to eq({})
    end
  end
  
  context 'with provider returning null mention ids' do
    let(:mock_client_with_null_mentions) do
      double('mock_client_null_mentions').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil, key_phrase_prompt: nil, sentiment_prompt: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                sentiment: :positive,
                segment: entries[0][:segment]
              }
            ],
            phrases: [
              {
                phrase: "checkout experience",
                mentions: nil  # Null mentions
              }
            ]
          }
        end
      end
    end
    
    subject { described_class.new(provider_client: mock_client_with_null_mentions) }
    
    it 'handles null mentions gracefully' do
      result = subject.extract(entries)
      
      checkout_phrase = result[:phrases].first
      expect(checkout_phrase[:mentions]).to eq([])
      expect(checkout_phrase[:summary][:total_mentions]).to eq(0)
    end
  end
  
  context 'with responses having no sentiment' do
    let(:mock_client_no_sentiment) do
      double('mock_client_no_sentiment').tap do |client|
        allow(client).to receive(:extract_batch) do |entries, question: nil, key_phrase_prompt: nil, sentiment_prompt: nil|
          {
            responses: [
              {
                id: "r_1",
                sentence: entries[0][:answer],
                # No sentiment field
                segment: entries[0][:segment]
              }
            ],
            phrases: [
              {
                phrase: "checkout experience",
                mentions: ["r_1"]
              }
            ]
          }
        end
      end
    end
    
    subject { described_class.new(provider_client: mock_client_no_sentiment) }
    
    it 'defaults to neutral sentiment when not provided' do
      result = subject.extract(entries)
      
      checkout_phrase = result[:phrases].first
      expect(checkout_phrase[:summary][:sentiment_distribution][:neutral]).to eq(1)
      expect(checkout_phrase[:summary][:sentiment_distribution][:positive]).to eq(0)
      expect(checkout_phrase[:summary][:sentiment_distribution][:negative]).to eq(0)
    end
  end
end