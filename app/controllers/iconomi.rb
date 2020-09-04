StephenReid::App.controller do
  get '/iconomi' do
    @p = params[:p]
    @favicon = 'moon.png'
    erb :iconomi
  end

  get '/loopring' do
    erb :loopring
  end

  get '/strategy' do
    @favicon = 'moon.png'
    erb :strategy
  end

  get '/ccowl/:p' do
    halt unless params[:p] == ENV['SITE_SECRET']
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

  ###

  post '/strategy/:p/bail' do
    halt unless params[:p] == ENV['SITE_SECRET']
    redirect "/iconomi/#{ENV['SITE_SECRET']}/bail"
  end

  get '/strategy/:p/bail' do
    halt unless params[:p] == ENV['SITE_SECRET']
    Strategy.bail
    sleep 5
    redirect "/iconomi/#{ENV['SITE_SECRET']}"
  end

  get '/strategy/:p/rebalance' do
    halt unless params[:p] == ENV['SITE_SECRET']
    Strategy.rebalance(force: params[:force])
    sleep 5
    redirect "/iconomi/#{ENV['SITE_SECRET']}"
  end
end
