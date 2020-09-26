StephenReid::App.controller do
  before do
    @favicon = 'moon.png'
  end

  get '/loopring' do
    erb :'crypto/loopring'
  end

  get '/coins' do
    @coins = Coin.where(
      :hidden.ne => true,
      :market_cap_rank.ne => nil,
      :market_cap.gte => 1_000_000,
      :total_volume.gte => 1_000_000
    ).order('price_change_percentage_24h_in_currency desc').limit(20)
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

  get '/coins/:slug/star' do
    coin = Coin.find_by(slug: params[:slug])
    coin.update_attribute(:starred, true)
    200
  end

  get '/coins/:slug/unstar' do
    coin = Coin.find_by(slug: params[:slug])
    coin.update_attribute(:starred, nil)
    200
  end

  get '/assets/:id/multiplier' do
    asset = Asset.find(params[:id])
    partial :'crypto/multiplier', locals: { asset: asset }
  end

  post '/assets/:id/multiplier' do
    asset = Asset.find(params[:id])
    asset.update_attribute(:multiplier, params[:multiplier])
    200
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

  get '/iconomi' do
    @p = params[:p]
    erb :'crypto/iconomi'
  end

  get '/strategy' do
    erb :'crypto/strategy'
  end

  get '/strategy/table' do
    partial :'crypto/strategy_table'
  end

  # post '/strategy/:p/bail' do
  #   halt unless params[:p] == ENV['SITE_SECRET']
  #   redirect "/strategy/#{ENV['SITE_SECRET']}/bail"
  # end
  #
  # get '/strategy/:p/bail' do
  #   halt unless params[:p] == ENV['SITE_SECRET']
  #   Strategy.delay.bail
  #   redirect '/strategy'
  # end
  #
  # get '/strategy/:p/rebalance' do
  #   halt unless params[:p] == ENV['SITE_SECRET']
  #   Strategy.delay.rebalance(force: params[:force])
  #   redirect '/strategy'
  # end
end
