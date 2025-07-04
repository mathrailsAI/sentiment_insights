module SentimentInsights
  class Configuration
    attr_accessor :provider, :openai_api_key, :aws_region, :claude_api_key

    def initialize
      @provider = :openai
      @openai_api_key = ENV["OPENAI_API_KEY"]
      @claude_api_key = ENV["CLAUDE_API_KEY"]
      @aws_region = "us-east-1"
    end
  end
end