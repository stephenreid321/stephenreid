StephenReid::App.controller do
  get '/crypto-investing' do
    @title = 'Crypto investing: a very short introduction'
    @og_desc = 'This is not financial advice'
    @og_image = "#{ENV['BASE_URI']}/images/crypto-investing-2.jpg"
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
    asset.update_attribute(:multiplier, params[:multiplier])
    200
  end
end
