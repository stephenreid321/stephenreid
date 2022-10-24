StephenReid::App.controller do
  before do
    halt 200 unless current_account || Padrino.env == :development
  end

  get '/tweets' do
    redirect '/tweets/1h/likes'
  end

  get '/tweets/:timeframe/:likes_or_rts' do
    @tweets = Tweet.all.select do |t|
      t = t.data
      t['age'] < (case params[:timeframe]; when '7d' then 7.days; when '24h' then 24.hours; when '1h' then 1.hour; end)
    end.sort_by do |t|
      t = t.data
      t["#{params[:likes_or_rts]}_per_follower_per_second"]
    end.reverse[0..19]
    erb :tweets
  end
end
