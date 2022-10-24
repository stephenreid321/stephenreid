StephenReid::App.controller do
  before do
    halt 200 unless current_account || Padrino.env == :development
  end

  get '/tweets' do
    redirect '/tweets/7d'
  end

  get '/tweets/7d' do
    @tweets = Tweet.all.sort_by do |t|
                t = t.data
                t['likes_per_follower_per_second']
              end.reverse[0..19]
    erb :tweets
  end

  get '/tweets/24h' do
    @tweets = Tweet.all.select do |t|
                t = t.data
                t['age'] < 24.hours
              end.sort_by do |t|
                t = t.data
                t['likes_per_follower_per_second']
              end.reverse[0..19]
    erb :tweets
  end

  get '/tweets/1h' do
    @tweets = Tweet.all.select do |t|
                t = t.data
                t['age'] < 1.hour
              end.sort_by do |t|
                t = t.data
                t['likes_per_follower_per_second']
              end.reverse[0..19]
    erb :tweets
  end
end
