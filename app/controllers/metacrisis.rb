StephenReid::App.controller do
  before do
    @hide_sponsors = true
    @title = 'Daniel Schmachtenberger on the Metacrisis'
  end

  get '/metacrisis', cache: true do
    expires 1.hour.to_i
    erb :'metacrisis/metacrisis'
  end

  get '/metacrisis/terms/:term' do
    redirect "/metacrisis/terms/#{params[:term].singularize}" if params[:term] != params[:term].singularize && Vterm.find_by(term: params[:term].singularize)
    @vterm = Vterm.find_by(term: params[:term]) || not_found
    @videos = @vterm.videos.paginate(page: params[:page], per_page: 10)
    erb :'metacrisis/term'
  end

  get '/metacrisis/edges/:id' do
    @vedge = Vedge.find(params[:id]) || not_found
    @videos = @vedge.videos.paginate(page: params[:page], per_page: 10)
    erb :'metacrisis/edge'
  end

  get '/metacrisis/terms' do
    redirect '/metacrisis'
  end

  get '/metacrisis/discover' do
    stops = STOPS
    stops += (Vterm.plurals + Vterm.interesting).uniq
    stops += Vterm.terms_to_tidy

    text = []
    Video.all.sample(20).each do |video|
      text << video.text
    end
    text = text.flatten.join(' ').downcase
    words = text.split(' ')
    @word_frequency = words.reject { |a| stops.include?(a) || a.length < 4 }.each_with_object(Hash.new(0)) { |word, counts| counts[word] += 1 }
    @phrase2_frequency = words.each_cons(2).reject { |a, b| stops.include?("#{a} #{b}") || (stops.include?(a) || stops.include?(b)) || (a.length < 4 || b.length < 4) }.each_with_object(Hash.new(0)) { |word, counts| counts[word.join(' ')] += 1 }
    erb :'metacrisis/discover'
  end
end
