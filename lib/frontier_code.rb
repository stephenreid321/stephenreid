require 'json'

module FrontierCode
  DATA_URL = 'https://cognition.com/data/frontiercode-leaderboard/data.json'
  VERSION = 'v1_1'
  DATASET = 'main'
  LAB_MATCHERS = [
    [/\AClaude/i, 'Anthropic'],
    [/\AGPT/i, 'OpenAI'],
    [/\AGrok/i, 'xAI'],
    [/\ASWE/i, 'Cognition'],
    [/\AKimi/i, 'Moonshot'],
    [/\AComposer/i, 'Cursor'],
    [/\AGLM/i, 'Zhipu'],
    [/\ADeepSeek/i, 'DeepSeek'],
    [/\AMiniMax/i, 'MiniMax'],
    [/\AInkling/i, 'Thinking Machines'],
    [/\AQwen/i, 'Alibaba'],
    [/\ANemotron/i, 'NVIDIA'],
    [/\AGemini/i, 'Google'],
    [/\AMistral/i, 'Mistral']
  ].freeze

  class << self
    def rows
      payload = JSON.parse(Faraday.get(DATA_URL).body)
      version = payload[VERSION] || {}
      data = version['data'] || {}
      harnesses = version['harness'] || {}
      lab_colors = version['lab_colors'] || {}

      rows = []
      data.each do |model, efforts|
        lab = lab_for(model)
        (efforts || {}).each do |effort, subsets|
          metrics = (subsets || {})[DATASET] || {}
          score = metrics['new_score']
          next if score.nil?

          rows << {
            'id' => "#{model}-#{effort}",
            'model' => model,
            'effort' => effort,
            'harness' => harnesses[model],
            'lab' => lab,
            'labColor' => lab_colors[lab],
            'displayLabel' => display_label(model, effort),
            'score' => score.to_f,
            'passRate' => metrics['correct']&.to_f,
            'flagRate' => metrics['flagged_rate']&.to_f,
            'cost' => metrics['cost']&.to_f,
            'tokens' => metrics['tokens']&.to_f
          }
        end
      end

      rows.sort_by { |row| -row['score'] }
    rescue Faraday::Error, JSON::ParserError
      []
    end

    private

    def display_label(model, effort)
      return model if effort.to_s.strip == '' || effort == 'none'

      "#{model} (#{effort})"
    end

    def lab_for(model)
      match = LAB_MATCHERS.find { |pattern, _lab| model.match?(pattern) }
      match ? match[1] : 'Other'
    end
  end
end
