require 'json'

module FrontierCode
  DATA_URL = 'https://cognition.com/data/frontiercode-leaderboard/data.json'
  VERSION = 'v1_1'
  DATASET = 'main'

  class << self
    def rows
      payload = JSON.parse(Faraday.get(DATA_URL).body)
      version = payload[VERSION] || {}
      data = version['data'] || {}
      harnesses = version['harness'] || {}

      rows = []
      data.each do |model, efforts|
        lab = EvalColors.lab_for(model) || 'Other'
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
            'labColor' => EvalColors.hex(lab),
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
  end
end
