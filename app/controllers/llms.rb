StephenReid::App.controller do
  get '/llms', cache: true do
    @container_class = 'container-fluid'
    @stylesheet = 'light'
    @index_attributes = %w[intelligence agentic coding omniscience openness]
    @title = 'LLMs'
    @models = ArtificialAnalysis.llm_models

    erb :llms
  end
end
