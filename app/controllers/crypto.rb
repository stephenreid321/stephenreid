StephenReid::App.controller do
  before do
    @favicon = 'moon.png'
    @og_desc = nil
    @og_image = nil
  end

  get '/coins' do
    redirect '/coins/tag/holding'
  end

  get '/coins/tag/:tag' do
    Tag.update_holdings
    erb :'crypto/coins'
  end

  get '/coins/table/:tag' do
    partial :'crypto/coin_table', locals: { coins: Coin.where(
      tag: Tag.find_by(name: params[:tag])
    ).order('price_change_percentage_24h_in_currency desc') }
  end

  post '/coins/table/:tag' do
    sign_in_required!
    Coin.symbol(params[:symbol]).update_attribute(:tag_id, Tag.find_or_create_by(name: params[:tag]).id)
    200
  end

  get '/coins/:slug' do
    coin = Coin.find_by(slug: params[:slug])
    coin.remote_update if coin.updated_at < 5.minutes.ago || Padrino.env == :development
    partial :'crypto/coin', locals: { coin: coin }
  end

  get '/coins/:slug/hide' do
    sign_in_required!
    coin = Coin.find_by(slug: params[:slug])
    coin.update_attribute(:tag_id, nil)
    200
  end

  get '/coins/:slug/star' do
    sign_in_required!
    coin = Coin.find_by(slug: params[:slug])
    coin.update_attribute(:starred, true)
    coin.remote_update
    200
  end

  get '/coins/:slug/unstar' do
    sign_in_required!
    coin = Coin.find_by(slug: params[:slug])
    coin.update_attribute(:starred, nil)
    coin.remote_update
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

  post '/strategy/:p/bail' do
    halt unless params[:p] == ENV['SITE_SECRET']
    redirect "/strategy/#{ENV['SITE_SECRET']}/bail"
  end

  get '/strategy/:p/bail' do
    halt unless params[:p] == ENV['SITE_SECRET']
    Strategy.delay.bail
    redirect '/strategy'
  end

  get '/strategy/:p/rebalance' do
    halt unless params[:p] == ENV['SITE_SECRET']
    Strategy.delay.rebalance(force: params[:force])
    redirect '/strategy'
  end

  get '/assets/:id/multiplier' do
    asset = Asset.find(params[:id])
    partial :'crypto/multiplier', locals: { asset: asset }
  end

  post '/assets/:id/multiplier' do
    sign_in_required!
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
end
