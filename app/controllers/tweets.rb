StephenReid::App.controller do
  before do
    @hide_sponsors = true
  end

  get '/tweets' do
    @title = 'Tweets'
    @favicon = 'twitter.png'
    @timeline = params[:timeline] || 'Home'
    @from = params[:from] || '7d'
    @to = params[:to] || '3d'
    @t1 = case @from
          when '0' then 0
          when '3h' then 3.hours
          when '12h' then 12.hours
          when '24h' then 24.hours
          when '3d' then 3.days
          when '7d' then 7.days
          end
    @t2 = case @to
          when '0h' then 0
          when '3h' then 3.hours
          when '12h' then 12.hours
          when '24h' then 24.hours
          when '3d' then 3.days
          when '7d' then 7.days
          end
    @tweets = Tweet.and(timeline: @timeline).select do |t|
      t = t.data
      t['age'] >= @t1 && t['age'] < @t2
    end.sort_by do |t|
      t = t.data
      t["#{params[:stat] ||= 'likes'}_per_follower_per_second"]
    end.reverse[0..19]
    erb :tweets
  end
end
