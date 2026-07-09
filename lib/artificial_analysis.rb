require 'digest'
require 'json'
require 'openssl'
require 'stringio'
require 'zlib'

module ArtificialAnalysis
  BASE_URL = 'https://artificialanalysis.ai'
  MANIFEST_PATTERN = /"path":"(\/data\/[^"]+\.txt)","key":"([a-f0-9]+)"/.freeze

  class << self
    def llm_models
      body = fetch_models_page
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

    private

    def fetch_models_page
      Faraday.get("#{BASE_URL}/models") { |req| req.headers['RSC'] = '1' }.body.force_encoding('UTF-8').scrub
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
  end
end
