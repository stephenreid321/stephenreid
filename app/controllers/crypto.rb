StephenReid::App.controller do
  before do
    @favicon = 'moon.png'
    @og_desc = nil
    @og_image = nil
  end

  get '/coins' do
    redirect 'https://autopia.co/u/stephenreid321'
  end

  get '/crypto-investing' do
    @title = 'Crypto investing: a very short introduction'
    @og_desc = 'This is not financial advice'
    @og_image = "#{ENV['BASE_URI']}/images/crypto-investing-2.jpg"
    erb :'crypto/crypto_investing'
  end

  get '/metastrategy' do
    @title = 'Metastrategy'
    erb :'crypto/metastrategy'
  end

  get '/metastrategy/verify' do
    Asset.where(:verified.ne => true, :excluded.ne => true).set(verified: true)
    Strategy.where(:verified.ne => true, :excluded.ne => true).set(verified: true)
    redirect '/metastrategy'
  end

  get '/iconomi', cache: true do
    unless Padrino.env == :development
      cache_key { request.path + '?' + params.select { |k, _v| %w[funds investment].include?(k) }.to_param }
      expires 1.hour.to_i
    end
    @title = 'ICONOMI strategy evaluator'
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
    redirect '/metastrategy'
  end

  get '/strategy/:p/rebalance' do
    halt unless params[:p] == ENV['SITE_SECRET']
    Strategy.delay.rebalance(force: params[:force])
    redirect '/metastrategy'
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
