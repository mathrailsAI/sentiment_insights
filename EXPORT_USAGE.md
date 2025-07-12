# SentimentInsights Export Feature Guide

The SentimentInsights gem now includes comprehensive export functionality for all analysis results. Export your sentiment analysis, entity extraction, and key phrase results to CSV and Excel formats with advanced filtering and customization options.

## 🚀 Quick Start

```ruby
# Run your analysis as usual
result = SentimentInsights::Insights::Sentiment.new.analyze(entries)

# Export to CSV (simplest usage)
result.to_csv("my_analysis.csv")

# Export to Excel
result.to_excel("my_analysis.xlsx")

# Auto-detect format from filename
result.export("my_analysis.csv")  # Creates CSV
result.export("my_analysis.xlsx") # Creates Excel
```

## 📊 CSV Export Structure

### Sentiment Analysis CSV
```csv
response_id,text,sentiment_label,sentiment_score,segment_age_group,segment_region,timestamp
r_1,"I love this product!",positive,0.9,18-25,North,2024-06-28T10:30:00Z
r_2,"Service was terrible",negative,-0.8,26-35,South,2024-06-28T10:31:00Z

SUMMARY STATISTICS
Total Responses,150
Positive Count,90
Positive Percentage,60.0%
Net Sentiment Score,40.0

SEGMENT ANALYSIS  
Segment Type,Segment Value,Total Count,Positive %,Neutral %,Negative %,Net Score
Age Group,18-25,75,65.3%,18.7%,16.0%,49.3
Age Group,26-35,45,53.3%,22.2%,24.4%,28.9
```

### Entity Extraction CSV
```csv
response_id,text,entities_found,segment_age_group,segment_region,timestamp
r_1,"Apple released iPhone",apple:ORGANIZATION,iphone:PRODUCT,18-25,North,2024-06-28T10:30:00Z

SUMMARY STATISTICS
Total Unique Entities,25
Organizations Mentioned,8
Most Mentioned Entity,apple (5 times)

ENTITY DETAILS
Entity,Type,Total Mentions,Response IDs,Segment Distribution
apple,ORGANIZATION,5,"r_1,r_3,r_7",age_group_18-25:3,age_group_26-35:2
```

### Key Phrases CSV
```csv
response_id,text,sentiment,sentiment_score,key_phrases_found,segment_age_group,timestamp
r_1,"Great customer service!",positive,0.8,"customer service,great experience",18-25,2024-06-28T10:30:00Z

PHRASE DETAILS
Phrase,Total Mentions,Response IDs,Sentiment Distribution,Segment Distribution
customer service,8,"r_1,r_4,r_7",positive:5,neutral:2,negative:1,age_group_18-25:4
```

## 🎛️ Advanced Export Options

### Basic Configuration
```ruby
# Export with custom options
result.to_csv("analysis.csv", {
  include_summary: true,      # Include summary statistics
  include_segments: true,     # Include segment analysis  
  include_timestamp: true,    # Add timestamp column
  timestamp_format: "%Y-%m-%d %H:%M:%S"
})

# Skip summary and segments (responses only)
result.to_csv("responses_only.csv", {
  include_summary: false,
  include_segments: false
})
```

### Dynamic Segment Handling
The export system automatically detects and flattens all segment structures:

```ruby
entries = [
  { 
    answer: "Great product!", 
    segment: { 
      demographics: { age: "25-34", income: "high" },
      location: { country: "USA", state: "CA" },
      simple_field: "value"
    }
  }
]

result = analyzer.analyze(entries)
result.to_csv("complex_segments.csv")

# CSV headers will be:
# response_id,text,sentiment_label,sentiment_score,
# segment_demographics_age,segment_demographics_income,
# segment_location_country,segment_location_state,
# segment_simple_field,timestamp
```

## 🔍 Filtering and Custom Exports

### Fluent Interface
```ruby
# Method chaining for custom exports
result
  .responses_only                    # Skip summary sections
  .filter_sentiment(:positive)       # Only positive responses
  .filter_segments(age_group: ["18-25", "26-35"])  # Specific age groups
  .to_csv("young_positive_feedback.csv")
```

### Quick Filter Methods
```ruby
# Export only positive responses
result.export_positive(:csv, "positive_feedback.csv")

# Export only negative responses  
result.export_negative(:excel, "issues_to_address.xlsx")

# Export specific segments
result.export_by_segment(:age_group, ["18-25"], :csv, "young_users.csv")
result.export_by_segment(:region, ["North", "South"], :excel, "regional_analysis.xlsx")
```

### Advanced Filtering
```ruby
# Complex filter combinations
result.exporter({
  filter: {
    sentiment: [:positive, :neutral],  # Exclude negative
    segments: { 
      age_group: ["18-25", "26-35"],
      region: ["North", "West"] 
    }
  },
  include_summary: false
}).to_csv("filtered_analysis.csv")
```

## 📈 Excel Export Features

Excel exports include multiple worksheets:

1. **Responses** - Individual response data
2. **Summary** - Statistical summaries  
3. **Segment Analysis** - Breakdown by segments
4. **Entity Details** - Entity-specific analysis (entities only)
5. **Phrase Details** - Phrase-specific analysis (key phrases only)

```ruby
# Basic Excel export
result.to_excel("comprehensive_report.xlsx")

# Excel with custom options
result.to_excel("detailed_report.xlsx", {
  include_summary: true,
  include_segments: true
})
```

## 🚀 Batch Export

Export to multiple formats at once:

```ruby
# Export to both CSV and Excel
files = result.export_all("quarterly_analysis")
# Returns: { csv: "quarterly_analysis.csv", excel: "quarterly_analysis.xlsx" }

files.each do |format, filename|
  puts "#{format.upcase} exported to: #{filename}"
end
```

## 🔧 Advanced Usage with Exporter Class

For maximum control, use the Exporter class directly:

```ruby
exporter = result.exporter({
  include_summary: true,
  include_segments: true,
  filter: { sentiment: [:positive] }
})

# Multiple export operations
csv_file = exporter.to_csv("positive_analysis.csv")
excel_file = exporter.to_excel("positive_analysis.xlsx")

# Specialized exports
summary_only = exporter.to_csv_summary_only("summary.csv")
responses_only = exporter.to_csv_responses_only("responses.csv")
```

## 🎯 Use Cases

### Customer Feedback Analysis
```ruby
feedback = analyzer.analyze(customer_responses)

# Export all feedback
feedback.export_all("customer_feedback_analysis")

# Export issues that need attention
feedback.export_negative(:excel, "issues_to_resolve.xlsx")

# Export by customer segment
feedback.export_by_segment(:customer_tier, ["premium", "enterprise"], :csv, "premium_feedback.csv")
```

### Survey Response Processing
```ruby
survey_results = analyzer.analyze(survey_responses)

# Comprehensive report for stakeholders
survey_results.to_excel("survey_report.xlsx", {
  include_summary: true,
  include_segments: true
})

# Quick CSV for data team
survey_results
  .responses_only
  .to_csv("raw_survey_data.csv")
```

### Regional Analysis
```ruby
regional_analysis = analyzer.analyze(regional_data)

# Export by region
%w[North South East West].each do |region|
  regional_analysis.export_by_segment(:region, region, :csv, "#{region.downcase}_analysis.csv")
end
```

## 📋 File Naming

Auto-generated filenames include timestamps:
- `sentiment_analysis_20240628_103045.csv`
- `entities_analysis_20240628_103045.xlsx`
- `key_phrases_analysis_20240628_103045.csv`

## 🛠️ Installation Requirements

Add to your Gemfile:
```ruby
gem 'sentiment_insights', '~> 0.3.0'
gem 'rubyXL', '~> 3.4'  # For Excel export support
```

## 🔍 Error Handling

```ruby
begin
  result.to_excel("report.xlsx")
rescue => e
  puts "Excel export failed: #{e.message}"
  # Fallback to CSV
  result.to_csv("report.csv")
end
```

## 🎉 Integration Examples

### Rails Controller
```ruby
class AnalyticsController < ApplicationController
  def export_feedback
    entries = FeedbackResponse.includes(:customer).map do |response|
      {
        answer: response.comment,
        segment: {
          customer_tier: response.customer.tier,
          region: response.customer.region,
          product: response.product_name
        }
      }
    end

    result = SentimentInsights::Insights::Sentiment.new.analyze(entries)
    
    filename = result.to_excel("feedback_analysis_#{Date.current}.xlsx")
    
    send_file filename, 
      filename: "customer_feedback_analysis.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end
end
```

### Background Job
```ruby
class AnalysisExportJob < ApplicationJob
  def perform(survey_id, email)
    survey = Survey.find(survey_id)
    entries = survey.responses.map { |r| { answer: r.text, segment: r.metadata } }
    
    result = SentimentInsights::Insights::Sentiment.new.analyze(entries)
    files = result.export_all("survey_#{survey_id}_analysis")
    
    AnalysisMailer.send_results(email, files).deliver_now
  end
end
```

## 🚀 Performance Tips

1. **Use filtering** to reduce export size for large datasets
2. **Skip unnecessary sections** with `responses_only` for faster exports
3. **Batch processing** - split large datasets before analysis
4. **Background jobs** for large exports in web applications

The export system is designed to handle dynamic segment structures, large datasets, and provides maximum flexibility for different use cases while maintaining excellent performance.