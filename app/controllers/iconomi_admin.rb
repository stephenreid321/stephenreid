StephenReid::App.controller do
  before do
    sign_in_required!
  end

  get '/metastrategy/verify' do
    Asset.and(status: nil).set(status: 'verified')
    Strategy.and(status: nil).set(status: 'verified')
    redirect '/metastrategy'
  end

  get '/metastrategy/rebalance' do
    Strategy.delay.rebalance_without_update
    redirect '/metastrategy'
  end

  get '/metastrategy/propose' do
    Strategy.delay.propose_and_stash
    redirect '/metastrategy'
  end

  get '/metastrategy/n' do
    partial :'iconomi/n'
  end

  post '/metastrategy/n' do
    Stash.find_by(key: 'number_of_assets').update(value: params[:n])
    200
  end

  get '/assets/:id/multiplier' do
    asset = Asset.find(params[:id])
    partial :'iconomi/multiplier', locals: { asset: asset }
  end

  post '/assets/:id/multiplier' do
    asset = Asset.find(params[:id])
    asset.multiplier = params[:multiplier]
    asset.save
    200
  end
end
