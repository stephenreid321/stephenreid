StephenReid::App.controller do
  get '/iconomi' do
    @p = false
    @favicon = 'moon.png'
    erb :iconomi
  end

  get '/iconomi/:p' do
    @p = (params[:p] == ENV['ICN_PASSWORD'])
    @favicon = 'moon.png'
    erb :iconomi
  end

  post '/iconomi/:p/bail' do
    halt unless params[:p] == ENV['ICN_PASSWORD']
    redirect "/iconomi/#{ENV['ICN_PASSWORD']}/bail"
  end

  get '/iconomi/:p/bail' do
    halt unless params[:p] == ENV['ICN_PASSWORD']
    # Strategy.bail
    redirect "/iconomi/#{ENV['ICN_PASSWORD']}"
  end

  get '/iconomi/:p/post_structure' do
    halt unless params[:p] == ENV['ICN_PASSWORD']
    Strategy.post_structure
    redirect "/iconomi/#{ENV['ICN_PASSWORD']}"
  end
end
