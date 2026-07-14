require 'digest'
require 'json'
require 'openssl'
require 'stringio'
require 'zlib'

module ArtificialAnalysis
  BASE_URL = 'https://artificialanalysis.ai'
  MANIFEST_PATTERN = /"path":"(\/data\/[^"]+\.txt)","key":"([a-f0-9]+)"/.freeze
  DEFAULT_AGENT_CHART_KEYS = %w[deep-swe terminal-bench-v2 swe-atlas-qna].freeze

  class << self
    def llm_models
      body = fetch_page('/models')
      manifests(body).each do |path, key|
        payload = decrypt_manifest(path, key)
        next unless payload.is_a?(Hash)

        models = payload['models']
        return models.map { |model| normalize_llm_model(model) } if models.is_a?(Array)
      rescue OpenSSL::Cipher::CipherError, JSON::ParserError, Zlib::Error
        next
      end

      []
    end

    def coding_agents(chart_keys: DEFAULT_AGENT_CHART_KEYS)
      body = fetch_page('/agents/coding-agents')
      rows = extract_agent_benchmark_rows(body)
      rows.each do |row|
        components = row['evals'] || row['componentScores'] || []
        row['components_by_dataset'] = components.each_with_object({}) do |c, h|
          h[c['datasetIndexName']] = c
        end
      end
      rows.select! do |row|
        chart_keys.all? { |key| row.dig('components_by_dataset', key, 'mean', 'reward') }
      end
      fast_bases = rows.filter_map do |row|
        label = row['displayLabel']
        label.end_with?(' Fast') ? label.delete_suffix(' Fast') : nil
      end
      rows.select! { |row| !fast_bases.include?(row['displayLabel']) }
      times = rows.filter_map { |row| row.dig('mean', 'agentWallTimeSec')&.to_f }.select(&:positive?).sort
      if times.any?
        median_time = times.length.odd? ? times[times.length / 2] : (times[times.length / 2 - 1] + times[times.length / 2]) / 2.0
        max_time = 2 * median_time
        rows.select! { |row| row.dig('mean', 'agentWallTimeSec').to_f <= max_time }
      end
      rows.sort_by { |r| -(r['indexScore'] || 0).to_f }
    rescue JSON::ParserError
      []
    end

    private

    def fetch_page(path)
      Faraday.get("#{BASE_URL}#{path}") { |req| req.headers['RSC'] = '1' }.body.force_encoding('UTF-8').scrub
    end

    def manifests(body)
      body.scan(MANIFEST_PATTERN).uniq
    end

    def decrypt_manifest(path, key_hex)
      key = [key_hex].pack('H*')
      iv = Digest::SHA256.digest(key)[0, 12]
      encrypted = Faraday.get("#{BASE_URL}#{path}").body.b
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      cipher.auth_tag = encrypted[-16..]
      decrypted = cipher.update(encrypted[0...-16]) + cipher.final
      JSON.parse(Zlib::GzipReader.new(StringIO.new(decrypted)).read)
    end

    def normalize_llm_model(model)
      cost_per_task = model['intelligenceIndexCostPerTask']

      {
        'slug' => model['slug'],
        'name' => model['name'],
        'model_creators' => model['creator'],
        'release_date' => model['releaseDate'],
        'reasoning_model' => model['isReasoning'],
        'is_open_weights' => model['isOpenWeights'],
        'intelligence_index' => model['intelligenceIndex'],
        'agentic_index' => model['agenticIndex'],
        'coding_index' => model['codingIndex'],
        'omniscience_index' => model['omniscience'],
        'openness_index' => model.dig('openness', 'opennessIndex'),
        'speed' => model.dig('timescaleData', 'medianOutputSpeed'),
        'cost_per_task' => cost_per_task.is_a?(Hash) ? cost_per_task.dig('cost', 'total') : nil
      }
    end

    # Extract a JSON array value that follows `key` in an RSC payload, skipping
    # bracket characters that appear inside strings.
    def extract_json_array(body, key)
      bytes = body.b
      i = bytes.index(key.b)
      return nil unless i

      start = i + key.bytesize
      start += 1 while start < bytes.bytesize && bytes.byteslice(start, 1) =~ /\s/
      return nil unless bytes.byteslice(start, 1) == '['

      depth = 0
      in_string = false
      escape = false
      bytes.byteslice(start..).each_byte.with_index do |c, idx|
        if escape
          escape = false
          next
        end
        if in_string
          if c == 92 # backslash
            escape = true
          elsif c == 34 # double quote
            in_string = false
          end
          next
        end
        case c
        when 34 # double quote
          in_string = true
        when 91 # [
          depth += 1
        when 93 # ]
          depth -= 1
          return bytes.byteslice(start, idx + 1).force_encoding('UTF-8') if depth.zero?
        end
      end
      nil
    end

    # AA embeds the full agent list in `benchmarkRows`, with React Flight refs into
    # the smaller default `rows` array for the initially selected configurations.
    def extract_agent_benchmark_rows(body)
      rows_json = extract_json_array(body, '"rows":')
      benchmark_rows_json = extract_json_array(body, '"benchmarkRows":')
      return [] unless benchmark_rows_json

      rows = rows_json ? JSON.parse(rows_json) : []
      benchmark_rows = JSON.parse(benchmark_rows_json)
      resolved = benchmark_rows.map do |item|
        if item.is_a?(Hash)
          item
        elsif item.is_a?(String) && item.include?(':rows:')
          rows[item.split(':').last.to_i]
        end
      end.compact

      resolved.uniq { |row| row['id'] }
    rescue JSON::ParserError
      []
    end
  end
end
