StephenReid::App.controller do
  before do
    halt 200 unless current_account || Padrino.env == :development
  end

  get '/tweets' do
    @tweets = Tweet.all.select do |t|
      t = t.data
      t['age'] < (case (params[:timeframe] ||= '1h')
                  when '1h' then 1.hour
                  when '3h' then 3.hours
                  when '6h' then 6.hours
                  when '12h' then 12.hours
                  when '24h' then 24.hours
                  when '7d' then 7.days
                  end) && t['age'] >= (case params[:timeframe]
                                       when '1h' then 0
                                       when '3h' then 1.hour
                                       when '6h' then 3.hours
                                       when '12h' then 6.hours
                                       when '24h' then 12.hours
                                       when '7d' then 24.hours
                                       end)
    end.sort_by do |t|
      t = t.data
      t["#{params[:stat] ||= 'likes'}_per_follower_per_second"]
    end.reverse[0..19]
    erb :tweets
  end
end
