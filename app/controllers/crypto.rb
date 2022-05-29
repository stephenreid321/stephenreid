StephenReid::App.controller do
  get '/crypto-investing' do
    @title = 'Crypto investing: a very short introduction'
    erb :'crypto/crypto_investing'
  end

  get '/iconomi', cache: true do
    expires 1.hour.to_i
    @title = 'ICONOMI strategy evaluator'
    erb :'crypto/iconomi'
  end

  get '/metastrategy' do
    @title = 'Metastrategy'
    erb :'crypto/metastrategy'
  end

  get '/metastrategy/verify' do
    Asset.and(status: nil).set(status: 'verified')
    Strategy.and(status: nil).set(status: 'verified')
    redirect '/metastrategy'
  end

  get '/metastrategy/table' do
    partial :'crypto/metastrategy'
  end

  get '/metastrategy/:p/rebalance' do
    halt unless params[:p] == ENV['SITE_SECRET']
    Strategy.delay.rebalance
    redirect '/metastrategy'
  end

  get '/assets/:id/multiplier' do
    asset = Asset.find(params[:id])
    partial :'crypto/multiplier', locals: { asset: asset }
  end

  post '/assets/:id/multiplier' do
    sign_in_required!
    asset = Asset.find(params[:id])
    asset.multiplier = params[:multiplier]
    asset.save
    200
  end
end
