StephenReid::App.controller do
  before '/llms', '/agents' do
    @container_class = 'container-fluid'
    @stylesheet = 'light'
  end

  get '/llms', cache: true do
    @index_attributes = %w[intelligence agentic coding omniscience openness]
    @title = 'LLMs'
    @models = ArtificialAnalysis.llm_models

    erb :'artificial_analysis/llms'
  end

  get '/agents', cache: true do
    @title = 'Coding agents'
    @chart_keys = ArtificialAnalysis::DEFAULT_AGENT_CHART_KEYS
    @agent_rows = ArtificialAnalysis.coding_agents(chart_keys: @chart_keys)

    erb :'artificial_analysis/agents'
  end
end
