lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sentiment_insights/version"

Gem::Specification.new do |spec|
  spec.name          = "sentiment_insights"
  spec.version       = SentimentInsights::VERSION
  spec.authors       = ["mathrailsAI"]
  spec.email         = ["mathrails@gmail.com"]

  spec.summary       = "Analyze and extract sentiment insights from text data easily."
  spec.description   = "SentimentInsights is a Ruby gem that helps analyze sentiment from survey responses, feedback, and other text sources. Built for developers who need quick and actionable sentiment extraction."

  spec.homepage      = "https://github.com/mathrailsAI/sentiment_insights"
  spec.license       = "MIT"

  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/mathrailsAI/sentiment_insights"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "sentimental", "~> 1.4.0"
  spec.add_dependency "aws-sdk-comprehend", ">= 1.98.0"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "dotenv", "~> 2.8"
end
