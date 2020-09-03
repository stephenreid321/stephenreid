StephenReid::App.controller do
  get '/iconomi' do
    @p = params[:p]
    @favicon = 'moon.png'
    erb :iconomi
  end

  get '/loopring' do
    erb :loopring
  end

  get '/strategy/:p' do
    @p = (params[:p] == ENV['ICN_PASSWORD'])
    @favicon = 'moon.png'
    erb :strategy
  end

  post '/strategy/:p/bail' do
    halt unless params[:p] == ENV['ICN_PASSWORD']
    redirect "/iconomi/#{ENV['ICN_PASSWORD']}/bail"
  end

  get '/strategy/:p/bail' do
    halt unless params[:p] == ENV['ICN_PASSWORD']
    Strategy.bail
    200
  end

  get '/strategy/:p/post_structure' do
    halt unless params[:p] == ENV['ICN_PASSWORD']
    Strategy.post_structure(force: params[:force])
    200
  end

  get '/ccowl/:p' do
    halt unless params[:p] == ENV['ICN_PASSWORD']
    alerts = JSON.parse(Mechanize.new.get('https://ccowl.com/getAlerts?page=0&coins=BTC,ETH&alertType=1').body)['data']
    alerts.each do |alert|
      Alert.create(
        ccowl_id: alert['alert_id'],
        text: alert['text'],
        ticker: alert['ticker'],
        value: alert['value'],
        rule_id: alert['rule_id'],
        created_at: alert['created']
      )
    end
    200
  end
end
