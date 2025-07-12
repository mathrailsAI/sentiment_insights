# SentimentInsights

**SentimentInsights** is a Ruby gem for extracting sentiment, key phrases, and named entities from survey responses or free-form textual data. It offers a plug-and-play interface to different NLP providers, including OpenAI, Claude AI, and AWS.

---

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
    - [Sentiment Analysis](#sentiment-analysis)
    - [Key Phrase Extraction](#key-phrase-extraction)
    - [Entity Extraction](#entity-extraction)
- [Export & Output Formats](#export--output-formats)
- [Provider Options & Custom Prompts](#provider-options--custom-prompts)
- [Full Example](#full-example)
- [Contributing](#contributing)
- [License](#license)

---

## Installation

Add to your Gemfile:

```ruby
gem 'sentiment_insights'
```

Then install:

```bash
bundle install
```

Or install it directly:

```bash
gem install sentiment_insights
```

---

## Configuration

Configure the provider and (if using OpenAI, Claude AI, or AWS) your API key:

```ruby
require 'sentiment_insights'

# For OpenAI
SentimentInsights.configure do |config|
  config.provider = :openai
  config.openai_api_key = ENV["OPENAI_API_KEY"]
end

# For Claude AI
SentimentInsights.configure do |config|
  config.provider = :claude
  config.claude_api_key = ENV["CLAUDE_API_KEY"]
end

# For AWS
SentimentInsights.configure do |config|
  config.provider = :aws
  config.aws_region = 'us-east-1'
end

# For sentimental
SentimentInsights.configure do |config|
  config.provider = :sentimental
end
```

Supported providers:
- `:openai`
- `:claude`
- `:aws`
- `:sentimental` (local fallback, limited feature set)

---

## Usage

Data entries should be hashes with at least an `:answer` key. Optionally include segmentation info under `:segment`.

```ruby
entries = [
  { answer: "Amazon Checkout was smooth!", segment: { age_group: "18-25", gender: "Female" } },
  { answer: "Walmart Shipping was delayed.", segment: { age_group: "18-25", gender: "Female" } },
  { answer: "Target Support was decent.", segment: { age_group: "26-35", gender: "Male" } },
  { answer: "Loved the product!", segment: { age_group: "18-25", gender: "Male" } }
]
```

---

### Sentiment Analysis

Quickly classify and summarize user responses as positive, neutral, or negative — globally or by segment (e.g., age, region).

#### 🔍 Example Call

```ruby
insight = SentimentInsights::Insights::Sentiment.new
result = insight.analyze(entries)
```

With options:

```ruby
custom_prompt = <<~PROMPT
  For each of the following customer responses, classify the sentiment as Positive, Neutral, or Negative, and assign a score between -1.0 (very negative) and 1.0 (very positive).

            Reply with a numbered list like:
            1. Positive (0.9)
            2. Negative (-0.8)
            3. Neutral (0.0)
PROMPT

insight = SentimentInsights::Insights::Sentiment.new
result = insight.analyze(
  entries,
  question: "How was your experience today?",
  prompt: custom_prompt,
  batch_size: 10
)
```

#### Available Options (`analyze`)
| Option        | Type    | Description                                                            | Provider           |
|---------------|---------|------------------------------------------------------------------------|--------------------|
| `question`    | String  | Contextual question for the batch                                     | OpenAI, Claude only |
| `prompt`      | String  | Custom prompt text for LLM                                            | OpenAI, Claude only |
| `batch_size`  | Integer | Number of entries per completion call (default: 50)                  | OpenAI, Claude only |

#### 📾 Sample Output

```ruby
{:global_summary=>
   {:total_count=>5,
    :positive_count=>3,
    :neutral_count=>0,
    :negative_count=>2,
    :positive_percentage=>60.0,
    :neutral_percentage=>0.0,
    :negative_percentage=>40.0,
    :net_sentiment_score=>20.0},
 :segment_summary=>
   {:age=>
      {"25-34"=>
         {:total_count=>3,
          :positive_count=>3,
          :neutral_count=>0,
          :negative_count=>0,
          :positive_percentage=>100.0,
          :neutral_percentage=>0.0,
          :negative_percentage=>0.0,
          :net_sentiment_score=>100.0}},
    :top_positive_comments=>
      [{:answer=>
          "I absolutely loved the experience shopping with Everlane. The website is clean,\n" +
            "product descriptions are spot-on, and my jeans arrived two days early with eco-friendly packaging.",
        :score=>0.9}],
    :top_negative_comments=>
      [{:answer=>
          "The checkout flow on your site was a nightmare. The promo code from your Instagram campaign didn’t work,\n" +
            "and it kept redirecting me to the homepage. Shopify integration needs a serious fix.",
        :score=>-0.7}],
    :responses=>
      [{:answer=>
          "I absolutely loved the experience shopping with Everlane. The website is clean,\n" +
            "product descriptions are spot-on, and my jeans arrived two days early with eco-friendly packaging.",
        :segment=>{:age=>"25-34", :region=>"West"},
        :sentiment_label=>:positive,
        :sentiment_score=>0.9}]}}
```

---

### Key Phrase Extraction

Extract frequently mentioned phrases and identify their associated sentiment and segment spread.

```ruby
insight = SentimentInsights::Insights::KeyPhrases.new
result = insight.extract(entries)
```

With options:

```ruby
key_phrase_prompt = <<~PROMPT.strip
  Extract the most important key phrases that represent the main ideas or feedback in the sentence below.
  Ignore stop words and return each key phrase in its natural form, comma-separated.

  Question: %{question}

  Text: %{text}
PROMPT

sentiment_prompt = <<~PROMPT
  For each of the following customer responses, classify the sentiment as Positive, Neutral, or Negative, and assign a score between -1.0 (very negative) and 1.0 (very positive).

            Reply with a numbered list like:
            1. Positive (0.9)
            2. Negative (-0.8)
            3. Neutral (0.0)
PROMPT

insight = SentimentInsights::Insights::KeyPhrases.new
result = insight.extract(
  entries,
  question: "What are the recurring themes?",
  key_phrase_prompt: key_phrase_prompt,
  sentiment_prompt: sentiment_prompt
)
```

#### Available Options (`extract`)
| Option             | Type    | Description                                                | Provider           |
|--------------------|---------|------------------------------------------------------------|--------------------|
| `question`         | String  | Context question to help guide phrase extraction           | OpenAI, Claude only |
| `key_phrase_prompt`| String  | Custom prompt for extracting key phrases                   | OpenAI, Claude only |
| `sentiment_prompt` | String  | Custom prompt for classifying tone of extracted phrases    | OpenAI, Claude only |

#### 📾 Sample Output

```ruby
{:phrases=>
   [{:phrase=>"everlane",
     :mentions=>["r_1"],
     :summary=>
       {:total_mentions=>1,
        :sentiment_distribution=>{:positive=>1, :negative=>0, :neutral=>0},
        :segment_distribution=>{:age=>{"25-34"=>1}, :region=>{"West"=>1}}}}],
 :responses=>
   [{:id=>"r_1",
     :sentence=>
       "I absolutely loved the experience shopping with Everlane. The website is clean,\n" +
         "product descriptions are spot-on, and my jeans arrived two days early with eco-friendly packaging.",
     :sentiment=>:positive,
     :segment=>{:age=>"25-34", :region=>"West"}}]}
```

---

### Entity Extraction

```ruby
insight = SentimentInsights::Insights::Entities.new
result = insight.extract(entries)
```

With options:

```ruby
entity_prompt = <<~PROMPT.strip
  Identify brand names, competitors, and product references in the sentence below.
  Return each as a JSON object with "text" and "type" (e.g., BRAND, PRODUCT, COMPANY).

  Question: %{question}

  Sentence: "%{text}"
PROMPT

insight = SentimentInsights::Insights::Entities.new
result = insight.extract(
  entries,
  question: "Which products or brands are mentioned?",
  prompt: entity_prompt
)

```

#### Available Options (`extract`)
| Option      | Type    | Description                                       | Provider           |
|-------------|---------|---------------------------------------------------|--------------------|
| `question`  | String  | Context question to guide entity extraction       | OpenAI, Claude only |
| `prompt`    | String  | Custom instructions for entity extraction         | OpenAI, Claude only |

#### 📾 Sample Output

```ruby
{:entities=>
   [{:entity=>"everlane",
     :type=>"ORGANIZATION",
     :mentions=>["r_1"],
     :summary=>
       {:total_mentions=>1,
        :segment_distribution=>{:age=>{"25-34"=>1}, :region=>{"West"=>1}}}},
    {:entity=>"jeans",
     :type=>"PRODUCT",
     :mentions=>["r_1"],
     :summary=>
       {:total_mentions=>1,
        :segment_distribution=>{:age=>{"25-34"=>1}, :region=>{"West"=>1}}}},
    {:entity=>"24 hours",
     :type=>"TIME",
     :mentions=>["r_4"],
     :summary=>
       {:total_mentions=>1,
        :segment_distribution=>{:age=>{"45-54"=>1}, :region=>{"Midwest"=>1}}}}],
 :responses=>
   [{:id=>"r_1",
     :sentence=>
       "I absolutely loved the experience shopping with Everlane. The website is clean,\n" +
         "product descriptions are spot-on, and my jeans arrived two days early with eco-friendly packaging.",
     :segment=>{:age=>"25-34", :region=>"West"}},
    {:id=>"r_4",
     :sentence=>
       "I reached out to your Zendesk support team about a missing package, and while they responded within 24 hours,\n" +
         "the response was copy-paste and didn't address my issue directly.",
     :segment=>{:age=>"45-54", :region=>"Midwest"}}]}
```

---

## Export & Output Formats

SentimentInsights provides flexible export options for all analysis results. Export to CSV, Excel, or JSON formats with advanced filtering and customization.

### Quick Export Examples

```ruby
result = SentimentInsights::Insights::Sentiment.new.analyze(entries)

# Direct format methods
result.to_csv("analysis.csv")           # CSV file
result.to_json("analysis.json")         # JSON file  
result.to_excel("analysis.xlsx")        # Excel file

# Auto-detect format from filename
result.export("analysis.csv")           # Creates CSV
result.export("analysis.json")          # Creates JSON
result.export("analysis.xlsx")          # Creates Excel

# API-friendly formats (no files)
api_data = result.to_hash               # Structured Hash
json_string = result.to_json_string     # JSON string
```

### Advanced Export Options

```ruby
# Filtered exports
result.export_positive(:csv, "positive_feedback.csv")
result.export_negative(:excel, "issues_to_address.xlsx")

# Fluent interface with filtering
result
  .filter_sentiment(:positive)
  .filter_segments(age_group: ["18-25", "26-35"])
  .to_excel("young_positive_feedback.xlsx")

# Export all formats at once
files = result.export_all("comprehensive_analysis")
# Returns: { csv: "file.csv", json: "file.json", excel: "file.xlsx" }
```

### CSV Export Structure

```csv
response_id,text,sentiment_label,sentiment_score,segment_age_group,segment_region,timestamp
r_1,"I love this product!",positive,0.9,18-25,North,2024-06-28T10:30:00Z

SUMMARY STATISTICS
Total Responses,150
Positive Percentage,60.0%
Net Sentiment Score,40.0

SEGMENT ANALYSIS
Segment Type,Segment Value,Total Count,Positive %,Net Score
Age Group,18-25,75,65.3%,49.3
```

### JSON Export Structure

```json
{
  "metadata": {
    "export_timestamp": "2024-06-28T10:30:00Z",
    "analysis_type": "sentiment",
    "total_responses": 150,
    "provider_used": "claude"
  },
  "analysis": {
    "responses": [...],
    "global_summary": {...},
    "segment_summary": {...}
  }
}
```

**📋 For complete export documentation, see [EXPORT_USAGE.md](EXPORT_USAGE.md)**

---

## Provider Options & Custom Prompts

> ⚠️ All advanced options (`question`, `prompt`, `key_phrase_prompt`, `sentiment_prompt`, `batch_size`) apply only to the `:openai` and `:claude` providers.  
> They are safely ignored for `:aws` and `:sentimental`.

---

## 🔑 Environment Variables

### OpenAI

```bash
OPENAI_API_KEY=your_openai_key_here
```

### Claude AI

```bash
CLAUDE_API_KEY=your_claude_key_here
```

### AWS Comprehend

```bash
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_REGION=us-east-1
```

---

## 💎 Ruby Compatibility

- **Minimum Ruby version:** 2.7

---

## 🔮 Testing

```bash
bundle exec rspec
```

---

## 📋 Roadmap

- [x] Sentiment Analysis
- [x] Key Phrase Extraction
- [x] Entity Recognition
- [x] Export Functionality (CSV, Excel, JSON)
- [ ] Topic Modeling
- [ ] Visual Dashboard Add-on

---

## 📄 License

MIT License

---

## 🙌 Contributing

Pull requests welcome! Please open an issue to discuss major changes first.

---

## 💬 Acknowledgements

- [OpenAI GPT](https://platform.openai.com/docs)
- [Claude AI](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
- [AWS Comprehend](https://docs.aws.amazon.com/comprehend/latest/dg/what-is.html)
- [Sentimental Gem](https://github.com/7compass/sentimental)

