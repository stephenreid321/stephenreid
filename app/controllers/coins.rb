StephenReid::App.controller do
  before do
    halt 200 unless current_account
    @virtual_tags = %w[starred tagged wallets elsewhere 24h 7d 14d 30d 200d 1y market-cap-24h top-100 top-100-less-tagged starred-less-tagged holding-less-starred starred-less-holding]
    @container_class = 'container-fluid'
  end

  get '/coins' do
    redirect '/u/stephenreid321'
  end

  get '/u/:username' do
    redirect "/u/#{params[:username]}/tags/starred"
  end

  get '/u/:username/coins' do
    redirect "/u/#{params[:username]}/tags/starred"
  end

  get '/u/:username/tags' do
    @account = Account.find_by(username: params[:username]) || not_found
    @account.tags.update_holdings
    erb :'coins/tags'
  end

  get '/u/:username/tags/:tag' do
    @title = params[:tag]
    @account = Account.find_by(username: params[:username]) || not_found
    erb :'coins/coins'
  end

  get '/u/:username/tags/:tag/table' do
    @account = Account.find_by(username: params[:username]) || not_found
    partial :'coins/coin_table', locals: { coins: Coin.and(
      :id.in => @account.coinships.and(tag: @account.tags.find_by(name: params[:tag])).pluck(:coin_id)
    ).order('price_change_percentage_24h_in_currency desc') }
  end

  get '/u/:username/coins/:slug' do
    @account = Account.find_by(username: params[:username]) || not_found
    coin = Coin.find_by(slug: params[:slug])
    coin.remote_update
    partial :'coins/coin', locals: { coin: coin }
  end

  # sign_in_required

  get '/coins/add_tag/:tag' do
    sign_in_required!
    tag = current_account.tags.find_or_create_by(name: params[:tag].parameterize)
    redirect "/u/#{current_account.username}/tags/#{tag.name}"
  end

  get '/coins/delete_tag/:tag' do
    sign_in_required!
    tag = current_account.tags.find_by(name: params[:tag]).destroy
    redirect "/u/#{current_account.username}/tags"
  end

  get '/coins/rename_tag/:tag/:new' do
    sign_in_required!
    tag = current_account.tags.find_by(name: params[:tag])
    tag.update_attribute(:name, params[:new].parameterize)
    redirect "/u/#{current_account.username}/tags/#{tag.name}"
  end

  post '/coins/tag/:tag' do
    sign_in_required!
    if coin = (Coin.symbol(params[:symbol]) || Coin.find_by(slug: params[:symbol]))
      coinship = current_account.coinships.find_or_create_by(coin: coin)
      coinship.tag = current_account.tags.find_by(name: params[:tag])
      coinship.save
    end
    current_account.tags.update_holdings
    200
  end

  get '/coins/:coin_id/hide' do
    sign_in_required!
    coinship = current_account.coinships.find_by(coin: params[:coin_id])
    coinship.try(:destroy)
    current_account.tags.update_holdings
    200
  end

  get '/coins/:coin_id/star' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:starred, true)
    coinship.remote_update
    200
  end

  get '/coins/:coin_id/unstar' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:starred, nil)
    200
  end

  post '/coins/:coin_id/units_elsewhere' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:units_elsewhere, params[:units_elsewhere])
    200
  end

  post '/coins/:coin_id/market_cap_rank_prediction' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:market_cap_rank_prediction, params[:p])
    200
  end

  post '/coins/:coin_id/market_cap_rank_prediction_conviction' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:market_cap_rank_prediction_conviction, params[:p])
    200
  end
end
