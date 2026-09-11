StephenReid::App.controller do
  before '/llms', '/agents' do
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
end
