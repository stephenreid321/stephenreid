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
    if params[:tag] == 'uniswap'
      agent = Mechanize.new
      @uniswap = []
      Coin.where(:uniswap_volume.ne => nil).set(uniswap_volume: nil)
      JSON.parse(agent.get('https://api.coingecko.com/api/v3/exchanges/uniswap').body)['tickers'].each do |ticker|
        if coin = Coin.find_by(slug: ticker['coin_id'])
          coin.update_attribute(:uniswap_volume, ticker['converted_volume']['eth'])
        end
        @uniswap << ticker['coin_id']
      end
    elsif params[:tag] == 'sushiswap'
      agent = Mechanize.new
      @sushiswap = []
      Coin.where(:sushiswap_volume.ne => nil).set(sushiswap_volume: nil)
      JSON.parse(agent.get('https://api.coingecko.com/api/v3/exchanges/sushiswap').body)['tickers'].each do |ticker|
        if coin = Coin.find_by(slug: ticker['coin_id'])
          coin.update_attribute(:sushiswap_volume, ticker['converted_volume']['eth'])
        end
        @sushiswap << ticker['coin_id']
      end
    elsif params[:tag] == 'defi-pulse'
      agent = Mechanize.new
      @defi_pulse = []
      Coin.where(:tvl.ne => nil).set(tvl: nil)
      JSON.parse(agent.get('https://defipulse.com/').search('#__NEXT_DATA__').inner_html)['props']['initialState']['coin']['projects'].each do |project|
        if coin = Coin.find_by(defi_pulse_name: project['name'])
          coin.update_attribute(:tvl, project['value']['tvl']['ETH']['value'])
          @defi_pulse << coin.slug
        end
      end
    end
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

  get '/metastrategy' do
    erb :'crypto/metastrategy'
  end

  get '/iconomi' do
    @p = params[:p]
    erb :'crypto/iconomi'
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
