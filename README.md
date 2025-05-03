# SentimentInsights 💬📊

**SentimentInsights** is a Ruby gem that helps you uncover meaningful insights from open-ended survey responses using Natural Language Processing (NLP). It supports multi-provider analysis via OpenAI, AWS Comprehend, or a local fallback engine.

---

## ✨ Features

### ✅ 1. Sentiment Analysis

Quickly classify and summarize user responses as positive, neutral, or negative — globally or by segment (e.g., age, region).

#### 🔍 Example Call

```ruby
insight = SentimentInsights::Insights::Sentiment.new
result = insight.analyze(entries)
```

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

### ✅ 2. Key Phrase Extraction

Extract frequently mentioned phrases and identify their associated sentiment and segment spread.

```ruby
insight = SentimentInsights::Insights::KeyPhrases.new
result = insight.extract(entries, question: question)
```

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

### ✅ 3. Entity Recognition

Identify named entities like organizations, products, and people, and track them by sentiment and segment.

```ruby
insight = SentimentInsights::Insights::Entities.new
result = insight.extract(entries, question: question)
```

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

### ✅ 4. Topic Modeling *(Coming Soon)*

Automatically group similar responses into topics and subthemes.

---

## 🔌 Supported Providers

| Feature            | OpenAI ✅       | AWS Comprehend ✅ | Sentimental (Local) ⚠️ |
| ------------------ | -------------- | ---------------- | ---------------------- |
| Sentiment Analysis | ✅              | ✅                | ✅                      |
| Key Phrases        | ✅              | ✅                | ❌ Not supported        |
| Entities           | ✅              | ✅                | ❌ Not supported        |
| Topics             | 🔜 Coming Soon | 🔜 Coming Soon   | ❌                      |

Legend: ✅ Supported | 🔜 Coming Soon | ❌ Not Available | ⚠️ Partial

---

## 📅 Example Input

```ruby
question = "What did you like or dislike about your recent shopping experience with us?"

entries = [
  {
    answer: "I absolutely loved the experience shopping with Everlane. The website is clean,\nproduct descriptions are spot-on, and my jeans arrived two days early with eco-friendly packaging.",
    segment: { age: "25-34", region: "West" }
  },
  {
    answer: "The checkout flow on your site was a nightmare. The promo code from your Instagram campaign didn’t work,\nand it kept redirecting me to the homepage. Shopify integration needs a serious fix.",
    segment: { age: "35-44", region: "South" }
  },
  {
    answer: "Apple Pay made the mobile checkout super fast. I placed an order while waiting for my coffee at Starbucks.\nGreat job optimizing the app UX—this is a game-changer.",
    segment: { age: "25-34", region: "West" }
  },
  {
    answer: "I reached out to your Zendesk support team about a missing package, and while they responded within 24 hours,\nthe response was copy-paste and didn't address my issue directly.",
    segment: { age: "45-54", region: "Midwest" }
  },
  {
    answer: "Shipping delays aside, I really liked the personalized note inside the box. Small gestures like that\nmake the Uniqlo brand stand out. Will definitely recommend to friends.",
    segment: { age: "25-34", region: "West" }
  }
]
```

---

## 🚀 Quick Start

```ruby
# Install the gem
$ gem install sentiment_insights

# Configure the provider
SentimentInsights.configure do |config|
  config.provider = :openai  # or :aws, :sentimental
end

# Run analysis
insight = SentimentInsights::Insights::Sentiment.new
result = insight.analyze(entries)
puts JSON.pretty_generate(result)
```

---

## 🔑 Environment Variables

### OpenAI

```bash
OPENAI_API_KEY=your_openai_key_here
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
- Tested on: 2.7, 3.0, 3.1, 3.2

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
- [ ] Topic Modeling
- [ ] CSV/JSON Export Helpers
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
- [AWS Comprehend](https://docs.aws.amazon.com/comprehend/latest/dg/what-is.html)
- [Sentimental Gem](https://github.com/7compass/sentimental)

---

## 📢 Questions?

File an issue or reach out on [GitHub](https://github.com/your-repo)
