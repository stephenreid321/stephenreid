require 'digest'
require 'json'
require 'openssl'
require 'stringio'
require 'zlib'

module ArtificialAnalysis
  BASE_URL = 'https://artificialanalysis.ai'
  MANIFEST_PATTERN = /"path":"(\/data\/[^"]+\.txt)","key":"([a-f0-9]+)"/.freeze
  TERMINAL_BENCH_4_TASKS = 66

  class << self
    def llm_models
      fetch_models('/models').map { |model| normalize_llm_model(model) }
    end

    def terminal_bench_4_rows
      fetch_models('/evaluations/terminalbench-4-0').filter_map do |model|
        score = model['terminalBench40']
        next if score.nil? || model['deprecated']

        tokens = model.dig('canonicalEvalTokenCounts', 'terminalBench40') || {}
        output_tokens = tokens['answer'].to_f + tokens['reasoning'].to_f
        creator = model['creator'] || {}
        lab = EvalColors.lab_for(model['name']) || creator['name'] || 'Other'

        {
          'id' => model['slug'],
          'model' => model.dig('release', 'name') || model['name'],
          'effort' => model['suffix'],
          'lab' => lab,
          'labColor' => EvalColors::LABS[lab] || creator['color'] || EvalColors::FALLBACK,
          'displayLabel' => model['shortName'] || model['name'],
          'releaseDate' => model['releaseDate'],
          'score' => score.to_f,
          'cost' => terminal_bench_4_cost(model, tokens),
          'tokens' => output_tokens.positive? ? output_tokens / TERMINAL_BENCH_4_TASKS : nil
        }
      end.sort_by { |row| -row['score'] }
    end

    private

    def fetch_models(path)
      body = fetch_page(path)
      manifests(body).each do |manifest_path, key|
        payload = decrypt_manifest(manifest_path, key)
        next unless payload.is_a?(Hash)

        models = payload['models']
        return models if models.is_a?(Array)
      rescue OpenSSL::Cipher::CipherError, JSON::ParserError, Zlib::Error
        next
      end

      []
    end

    # Matches AA's cost per task: uncached input is billed at the cache write
    # price, and cacheable input is split into hits and writes by cacheHitRate.
    def terminal_bench_4_cost(model, tokens)
      prices = model.values_at('price1mInputTokens', 'price1mOutputTokens', 'cacheHitPrice', 'cacheWritePrice', 'cacheHitRate')
      return nil if tokens.empty? || prices.any?(&:nil?)

      _input_price, output_price, hit_price, write_price, hit_rate = prices.map(&:to_f)
      cacheable = tokens['cacheableInput'].to_f
      uncached = tokens['input'].to_f - cacheable
      output = tokens['answer'].to_f + tokens['reasoning'].to_f
      total = (uncached * write_price) +
              (cacheable * hit_rate * hit_price) +
              (cacheable * (1 - hit_rate) * write_price) +
              (output * output_price)
      total / 1_000_000 / TERMINAL_BENCH_4_TASKS
    end

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
        'cost_per_task' => cost_per_task.is_a?(Hash) ? cost_per_task.dig('cost', 'total') : nil,
        'time_per_task' => model['intelligenceIndexTimePerTask']
      }
    end
  end
end
