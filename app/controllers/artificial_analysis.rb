StephenReid::App.controller do
  before '/llms', '/agents', '/frontiercode' do
    @container_class = 'container-fluid'
    @stylesheet = 'light'
  end

  get '/llms', cache: true do
    @index_attributes = %w[intelligence]
    @title = 'LLMs'
    @models = ArtificialAnalysis.llm_models

    erb :'artificial_analysis/llms'
  end

  get '/agents', cache: true do
    @title = 'Coding agents'
    @agent_rows = ArtificialAnalysis.coding_agents
    @chart_keys = ArtificialAnalysis.resolve_agent_chart_keys(@agent_rows)

    erb :'artificial_analysis/agents'
  end

  get '/frontiercode', cache: true do
    @title = 'FrontierCode'
    @frontiercode_rows = FrontierCode.rows
    @lab_colors = @frontiercode_rows.each_with_object({}) do |row, colors|
      colors[row['lab']] = row['labColor'] if row['lab'] && row['labColor']
    end

    erb :'artificial_analysis/frontiercode'
  end
end
