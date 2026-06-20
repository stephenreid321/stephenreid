StephenReid::App.controller do
  get '/llms', cache: true do
    @container_class = 'container-fluid'
    @stylesheet = 'light'
    @index_attributes = %w[intelligence agentic coding omniscience openness]
    @title = 'LLMs'

    response = Faraday.get('https://artificialanalysis.ai/models') do |req|
      req.headers['RSC'] = '1'
    end
    body = response.body.force_encoding('UTF-8').scrub

    # Artificial Analysis currently exposes the model rows in `defaultData`.
    models_json = extract_json_array(body, '"defaultData":')
    @models =
      begin
        models_json ? JSON.parse(models_json) : []
      rescue JSON::ParserError
        []
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
      # Normalize omniscience to follow the same pattern as other indices
      model['omniscience_index'] = model['omniscience'] if model['omniscience']

      cost_per_task = model['intelligenceIndexCostPerTask']
      model['cost_per_task'] = cost_per_task.dig('cost', 'total') if cost_per_task.is_a?(Hash)
    end

    erb :llms
  end
end
