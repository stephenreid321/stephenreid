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
    Strategy.bail
    redirect "/iconomi/#{ENV['ICN_PASSWORD']}"
  end

  get '/iconomi/:p/post_structure' do
    halt unless params[:p] == ENV['ICN_PASSWORD']
    Strategy.post_structure
    redirect "/iconomi/#{ENV['ICN_PASSWORD']}"
  end

  get '/iconomi/:p/ccowl' do
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
    redirect "/iconomi/#{ENV['ICN_PASSWORD']}"
  end

  get '/loopring' do
    erb :loopring
  end
end
