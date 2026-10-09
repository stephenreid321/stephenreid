StephenReid::App.controller do
  before do
    @container_class = 'container-fluid'
    @stylesheet = 'light'
  end

  get '/llms', cache: true do
    @index_attributes = %w[intelligence]
    @title = 'LLMs'
    @models = ArtificialAnalysis.llm_models

    erb :'evals/llms'
  end

  get '/frontiercode', cache: true do
    @title = 'FrontierCode'
    @frontiercode_rows = FrontierCode.rows
    @lab_colors = @frontiercode_rows.each_with_object({}) do |row, colors|
      colors[row['lab']] = row['labColor'] if row['lab'] && row['labColor']
    end

    erb :'evals/frontiercode'
  end

  get '/tb4', cache: true do
    @title = 'Terminal-Bench 4.0'
    @tb4_rows = ArtificialAnalysis.terminal_bench_4_rows
    @lab_colors = @tb4_rows.each_with_object({}) do |row, colors|
      colors[row['lab']] = row['labColor'] if row['lab'] && row['labColor']
    end

    erb :'evals/tb4'
  end

  get '/cursor', cache: true do
    @title = 'CursorBench'
    @cursorbench_rows = CursorBench.rows
    @family_colors = @cursorbench_rows.each_with_object({}) do |row, colors|
      colors[row['model']] = row['familyColor'] if row['model'] && row['familyColor']
    end

    erb :'evals/cursorbench'
  end
end
