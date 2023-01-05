StephenReid::App.controller do
  get '/metacrisis', cache: true do
    expires 1.hour.to_i
    erb :'metacrisis/metacrisis'
  end

  get '/metacrisis/terms' do
    redirect '/metacrisis'
  end

  get '/metacrisis/stats' do
    interesting = Video.interesting
    stops = STOPS
    stops += interesting
    stops += interesting.map { |x| x.pluralize }

    text = []
    Video.all.sort_by { |video| -video.text.length }.first(10).each do |video|
      text << video.text
    end
    text = text.flatten.join(' ').downcase
    words = text.split(' ')
    @word_frequency = words.reject { |a| stops.include?(a) || a.length < 4 }.each_with_object(Hash.new(0)) { |word, counts| counts[word] += 1 }
    @phrase2_frequency = words.each_cons(2).reject { |a, b| stops.include?("#{a} #{b}") || (stops.include?(a) || stops.include?(b)) || (a.length < 4 || b.length < 4) }.each_with_object(Hash.new(0)) { |word, counts| counts[word.join(' ')] += 1 }
    erb :'metacrisis/terms'
  end

  get '/metacrisis/terms/:term' do
    erb :'metacrisis/term'
  end
end
