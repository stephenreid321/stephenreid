StephenReid::App.controller do
  get '/agents', cache: true do
    @container_class = 'container-fluid'
    @stylesheet = 'light'
    @title = 'Coding agents'

    response = Faraday.get('https://artificialanalysis.ai/agents/coding-agents') do |req|
      req.headers['RSC'] = '1'
    end
    body = response.body.force_encoding('UTF-8').scrub

    rows_json = extract_json_array(body, '"rows":')
    @agent_rows =
      begin
        rows = rows_json ? JSON.parse(rows_json) : []
        rows.each do |row|
          row['components_by_dataset'] = (row['componentScores'] || []).each_with_object({}) do |c, h|
            h[c['datasetIndexName']] = c
          end
        end
        rows.sort_by { |r| -(r['indexScore'] || 0).to_f }
      rescue JSON::ParserError
        []
      end

    erb :agents
  end
end
