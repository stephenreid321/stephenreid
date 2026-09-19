module CursorBench
  PAGE_URL = 'https://cursor.com/evals'
  EFFORTS = ['Extra High', 'Minimal', 'Medium', 'High', 'Low', 'Max'].freeze

  class << self
    def rows
      body = Faraday.get(PAGE_URL) { |req|
        req.headers['User-Agent'] = 'Mozilla/5.0'
      }.body.force_encoding('UTF-8').scrub

      rows = []
      seen = {}
      Nokogiri::HTML(body).css('table tr').each do |tr|
        cells = tr.css('td').map { |td| td.text.gsub(/\s+/, ' ').strip }
        next unless cells.length >= 6

        _rank, label, score_text, cost_text, tokens_text, steps_text = cells
        next if label.to_s.strip == '' || !score_text.to_s.include?('%')
        next if seen[label]

        model, effort = split_label(label)
        lab = EvalColors.lab_for(model) || 'Other'
        seen[label] = true
        rows << {
          'id' => label,
          'model' => model,
          'effort' => effort,
          'lab' => lab,
          'labColor' => EvalColors.hex(lab),
          'familyColor' => EvalColors.hex(model),
          'displayLabel' => label,
          'score' => parse_percent(score_text),
          'cost' => parse_money(cost_text),
          'tokens' => parse_number(tokens_text),
          'steps' => parse_number(steps_text)
        }
      end

      rows.sort_by { |row| -row['score'].to_f }
    rescue Faraday::Error
      []
    end

    private

    def split_label(label)
      EFFORTS.sort_by { |effort| -effort.length }.each do |effort|
        suffix = " #{effort}"
        return [label.delete_suffix(suffix), effort] if label.end_with?(suffix)
      end
      [label, nil]
    end

    def parse_percent(text)
      text.to_s.tr('%', '').strip.to_f / 100.0
    end

    def parse_money(text)
      value = text.to_s.gsub(/[$,]/, '').strip
      return nil if value == ''

      value.to_f
    end

    def parse_number(text)
      value = text.to_s.gsub(',', '').strip
      return nil if value == ''

      value.include?('.') ? value.to_f : value.to_i
    end
  end
end
