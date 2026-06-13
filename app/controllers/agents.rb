StephenReid::App.controller do
  get '/agents', cache: true do
    @container_class = 'container-fluid'
    @stylesheet = 'light'
    @title = 'Coding agents'

    response = Faraday.get('https://artificialanalysis.ai/agents/coding-agents') do |req|
      req.headers['RSC'] = '1'
    end
    body = response.body.force_encoding('UTF-8').scrub

    @chart_keys = %w[deep-swe terminal-bench-v2 swe-atlas-qna]

    @agent_rows =
      begin
        rows = extract_agent_benchmark_rows(body)
        rows.each do |row|
          components = row['evals'] || row['componentScores'] || []
          row['components_by_dataset'] = components.each_with_object({}) do |c, h|
            h[c['datasetIndexName']] = c
          end
        end
        rows.select! do |row|
          @chart_keys.all? { |key| row.dig('components_by_dataset', key, 'mean', 'reward') }
        end
        fast_bases = rows.filter_map do |row|
          label = row['displayLabel']
          label.end_with?(' Fast') ? label.delete_suffix(' Fast') : nil
        end
        rows.select! { |row| !fast_bases.include?(row['displayLabel']) }
        rows.sort_by { |r| -(r['indexScore'] || 0).to_f }
      rescue JSON::ParserError
        []
      end

    erb :agents
  end
end
