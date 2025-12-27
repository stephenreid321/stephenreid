StephenReid::App.controller do
  
  get '/llms', cache: true do
    @container_class = 'container-fluid'
    @stylesheet = 'light'
    @index_attributes = %w[intelligence agentic coding math openness omniscience]
    
    response = Faraday.get('https://artificialanalysis.ai/models') do |req|
      req.headers['RSC'] = '1'
    end
    body = response.body.force_encoding('UTF-8').scrub

    # Extract the models array from the RSC response
    # The models are embedded in the React Server Components payload
    # There are two "models":[ arrays - the second one contains omniscience data
    first_models_idx = body.index('"models":[')
    models_match = first_models_idx && body.index('"models":[', first_models_idx + 1)
    if models_match
      # Find the full models array by locating its boundaries (use second occurrence)
      start_idx = body.index('"models":[', first_models_idx + 1) + 9
      # Count brackets to find the end of the array
      bracket_count = 0
      end_idx = start_idx
      body[start_idx..].each_char.with_index do |char, idx|
        bracket_count += 1 if char == '['
        bracket_count -= 1 if char == ']'
        if bracket_count.zero?
          end_idx = start_idx + idx
          break
        end
      end
      models_json = body[start_idx..end_idx]
      @models = JSON.parse(models_json)
    else
      @models = []
    end

    # Extract data from body and build lookup by model ID
    extract_model_data = lambda do |json_key, model_id_key, value_key|
      pattern = /"#{json_key}":\{[^}]+\}/
      result = {}
      body.scan(pattern).each do |match|
        data = JSON.parse("{#{match}}")[json_key]
        result[data[model_id_key]] = data[value_key] if data
      end
      result
    end

    openness_by_model_id = extract_model_data.call('openness', 'modelId', 'opennessIndex')
    speed_by_model_id = extract_model_data.call('timescaleData', 'model_id', 'median_output_speed')

    @models.each do |model|
      model['openness_index'] = openness_by_model_id[model['id']]
      model['speed'] = speed_by_model_id[model['id']]

      token_counts = model['intelligence_index_token_counts']
      host_models = model['host_models']
      primary_host_id = model['computed_performance_host_model_id']
      next unless token_counts && host_models&.any?

      input_tokens = token_counts['input_tokens'] || 0
      output_tokens = token_counts['output_tokens'] || 0

      # Use primary host model (same as AA site uses for their calculations)
      # Fallback: use most common price tier when no primary is set
      host = host_models.find { |hm| hm['id'] == primary_host_id }
      unless host
        non_free = host_models.select { |hm| (hm['price_1m_blended_3_to_1'] || 0) > 0 }
        host = non_free.min_by { |hm| hm['price_1m_blended_3_to_1'] }
      end
      next unless host && host['price_1m_input_tokens'] && host['price_1m_output_tokens']

      input_cost = input_tokens / 1_000_000.0 * host['price_1m_input_tokens']
      output_cost = output_tokens / 1_000_000.0 * host['price_1m_output_tokens']
      model['cost_to_run'] = input_cost + output_cost
    end

    erb :llms
  end

end