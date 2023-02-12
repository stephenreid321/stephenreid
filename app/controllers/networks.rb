StephenReid::App.controller do
  before do
    @hide_sponsors = true
    if params[:slug]
      @network = Network.find_by(slug: params[:slug]) || not_found
      @title = @network.name
    end
  end

  get '/metacrisis' do
    redirect '/k/daniel'
  end

  get '/metacrisis/terms' do
    redirect '/k/daniel'
  end

  get '/metacrisis/terms/:term' do
    redirect "/k/daniel/terms/#{params[:term]}"
  end

  get '/metacrisis/edges/:id' do
    redirect "/k/daniel/edges/#{params[:id]}"
  end

  get '/k' do
    if params[:slug]
      redirect "/k/#{params[:slug]}"
    else
      erb :'k/k'
    end
  end

  get '/k/:slug', cache: true do
    expires 1.hour.to_i
    erb :'k/network'
  end

  get '/k/:slug/terms/create/:term' do
    @vterm = @network.vterms.create(term: params[:term])
    200
  end

  get '/k/:slug/terms/:term' do
    redirect "/k/#{params[:slug]}/terms/#{params[:term].singularize}" if params[:term] != params[:term].singularize && @network.vterms.find_by(term: params[:term].singularize)
    @vterm = @network.vterms.find_by(term: params[:term]) || not_found
    @videos = @vterm.videos.paginate(page: params[:page], per_page: 10)
    erb :'k/term'
  end

  get '/k/:slug/edges/:id' do
    @vedge = @network.vedges.find(params[:id]) || not_found
    @videos = @vedge.videos.paginate(page: params[:page], per_page: 10)
    erb :'k/edge'
  end

  get '/k/:slug/discover' do
    stops = STOPS
    stops += (@network.plurals + @network.interesting).uniq
    stops += @network.vterms.terms_to_tidy

    text = []
    @network.videos.sample(20).each do |video|
      text << video.text
    end
    text = text.flatten.join(' ').downcase
    words = text.split(' ')
    @word_frequency = words.reject { |a| stops.include?(a) || a.length < 4 }.each_with_object(Hash.new(0)) { |word, counts| counts[word] += 1 }
    @phrase2_frequency = words.each_cons(2).reject { |a, b| stops.include?("#{a} #{b}") || (stops.include?(a) || stops.include?(b)) || (a.length < 4 || b.length < 4) }.each_with_object(Hash.new(0)) { |word, counts| counts[word.join(' ')] += 1 }
    erb :'k/discover'
  end
end
