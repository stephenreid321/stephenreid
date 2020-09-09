StephenReid::App.controller do
  get '/iconomi' do
    @p = params[:p]
    @favicon = 'moon.png'
    erb :'crypto/iconomi'
  end

  get '/loopring' do
    erb :'crypto/loopring'
  end

  get '/coins' do
    @coins = Coin.where(
      :hidden.ne => true,
      :market_cap_rank.ne => nil,
      :market_cap.gte => 1_000_000,
      :total_volume.gte => 1_000_000,
      :price_change_percentage_24h_in_currency.gt => 20
    ).order('price_change_percentage_24h_in_currency desc')
    erb :'crypto/coins'
  end

  get '/coins/:slug' do
    coin = Coin.find_by(slug: params[:slug])
    coin.update
    partial :'crypto/coin', locals: { coin: coin }
  end

  get '/coins/:slug/hide' do
    coin = Coin.find_by(slug: params[:slug])
    coin.update_attribute(:hidden, true)
    200
  end

  get '/strategy' do
    @favicon = 'moon.png'
    erb :'crypto/strategy'
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
