StephenReid::App.controller do
  before do
    @hide_sponsors = true
  end

  get '/tweets' do
    @title = 'Tweets'
    @favicon = 'twitter.png'
    @timeline = params[:timeline] || 'Home'
    @t1 = params[:t1] || '24h'
    @t2 = params[:t2] || '7d'
    @t1t = case @t1
           when '0' then 0
           when '3h' then 3.hours
           when '12h' then 12.hours
           when '24h' then 24.hours
           when '3d' then 3.days
           when '7d' then 7.days
           end
    @t2t = case @t2
           when '0' then 0
           when '3h' then 3.hours
           when '12h' then 12.hours
           when '24h' then 24.hours
           when '3d' then 3.days
           when '7d' then 7.days
           end
    @tweets = Tweet.and(:timeline => @timeline, :hidden.ne => true).select do |t|
      t = t.data
      t['age'] >= @t1t && t['age'] < @t2t
    end.sort_by do |t|
      t = t.data
      t["#{params[:stat] ||= 'likes'}_per_follower_per_second"]
    end.reverse[0..19]
    erb :tweets
  end

  get '/tweets/:id/hide' do
    tweet = Tweet.find(params[:id])
    tweet.update_attribute(:hidden, true)
    200
  end
  
end
