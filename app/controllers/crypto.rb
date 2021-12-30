StephenReid::App.controller do
  before do
    @favicon = 'moon.png'
  end

  get '/crypto-investing' do
    @title = 'Crypto investing: a very short introduction'
    @og_desc = 'This is not financial advice'
    @og_image = "#{ENV['BASE_URI']}/images/crypto-investing-2.jpg"
    erb :'crypto/crypto_investing'
  end

  get '/iconomi' do
    @title = 'ICONOMI strategy evaluator'
    erb :'crypto/iconomi'
  end

  get '/metastrategy' do
    @title = 'Metastrategy'
    erb :'crypto/metastrategy'
  end

  get '/metastrategy/verify' do
    Asset.and(:verified.ne => true, :excluded.ne => true).set(verified: true)
    Strategy.and(:verified.ne => true, :excluded.ne => true).set(verified: true)
    redirect '/metastrategy'
  end

  get '/metastrategy/table' do
    partial :'crypto/metastrategy'
  end

  get '/metastrategy/:p/rebalance' do
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
end
