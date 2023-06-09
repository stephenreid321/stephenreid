StephenReid::App.controller do
  before do
    @hide_sponsors = true
  end

  get '/tweets' do
    @title = 'Tweets'
    @favicon = 'twitter.png'
    @timeline = params[:timeline] || 'Home'
    @tweets = Tweet.and(timeline: @timeline).select do |t|
      t = t.data
      t['age'] < (case (params[:timeframe] ||= '7d')
                  when '3h' then 3.hours
                  when '12h' then 12.hours
                  when '24h' then 24.hours
                  when '3d' then 3.days
                  when '7d' then 7.days
                  end) && t['age'] >= (case params[:timeframe]
                                       when '3h' then 0
                                       when '12h' then 3.hours
                                       when '24h' then 12.hours
                                       when '3d' then 24.hours
                                       when '7d' then 3.days
                                       end)
    end.sort_by do |t|
      t = t.data
      t["#{params[:stat] ||= 'likes'}_per_follower_per_second"]
    end.reverse[0..19]
    erb :tweets
  end
end
