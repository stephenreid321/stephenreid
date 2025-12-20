StephenReid::App.controller do
  before do
    sign_in_required!
  end

  get '/organisations/:id/tagify' do
    @organisation = begin; Organisation.find(params[:id]); rescue StandardError; not_found; end
    @organisation.tagify
    200
  end

  get '/posts/:id/iframely' do
    @post = begin; Post.find(params[:id]); rescue StandardError; not_found; end
    @post.refresh_iframely
    200
  end

  get '/posts/:id/tagify' do
    @post = begin; Post.find(params[:id]); rescue StandardError; not_found; end
    unless @post['Title']
      @json = JSON.parse(@post['Iframely'])
      @post['Title'] = @json['meta']['title']
      @post['Body'] = @json['meta']['description']
      @post.save
    end
    @post.tagify
    @post.cast
    @post.bluesky
    200
  end

  post '/posts/:id/essay' do
    @post = begin; Post.find(params[:id]); rescue StandardError; not_found; end
    @post['Prompt'] = params[:prompt]
    @post['Generating essay'] = true
    @post.save
    Padrino.env == :development ? @post.generate_essay_without_delay : @post.generate_essay
    redirect "/posts/#{@post.id}"
  end

  get '/terms/tagify' do
    post_ids = []
    Term.all.each do |term|
      next if term['Posts']

      post_ids += Post.all(filter: "
    OR(
      FIND(LOWER('#{term['Name']}'), LOWER({Title})) > 0,
      FIND(LOWER('#{term['Name']}'), LOWER({Body})) > 0,
      FIND(LOWER('#{term['Name']}'), LOWER({Iframely})) > 0
    )
      ", sort: { 'Created at' => 'desc' }).map(&:id)
    end
    post_ids = post_ids.uniq
    unless post_ids.empty?
      puts "#{c = post_ids.length} posts"
      Post.find_many(post_ids).each_with_index do |post, i|
        puts "#{post['Title']} (#{i}/#{c})"
        post.tagify(skip_linking: true)
      end
    end
    200
  end

  get '/terms/:id/tagify' do
    @term = begin; Term.find(params[:id]); rescue StandardError; not_found; end
    @term.tagify
    200
  end

  get '/terms/create_edges' do
    Term.all(filter: "AND({Sources} = '', {Sinks} = '')").each do |term|
      puts term['Name']
      term.create_edges
    end
    200
  end

  get '/terms/:id/create_edges' do
    @term = begin; Term.find(params[:id]); rescue StandardError; not_found; end
    @term.create_edges
    200
  end

  get '/stats' do
    text = []
    hosts = []
    Post.all.each do |post|
      post_text = []
      json = JSON.parse(post['Iframely'])
      post_text << post['Title']
      if (b = post['Body']) && (!b.include?('use cookies') && !b.include?('use of cookies'))
        b = b.gsub(/Read [\d,]+ reviews from the world's largest community for readers. /, '')
        post_text << b
      end
      if json['meta']
        post_text << json['meta']['title'] if json['meta']['title']
        if (d = json['meta']['description'])
          d = d.gsub(/Read [\d,]+ reviews from the world's largest community for readers. /, '')
          post_text << d
        end
        post_text << json['meta']['category'] if json['meta']['category']
        post_text << json['meta']['keywords'].split(',').join(' ') if json['meta']['keywords']
      end
      text << post_text
      hosts << URI(post['Link']).host.gsub('www.', '')
    end

    terms = Term.all.map { |term| term['Name'].downcase }
    term_words = terms.map(&:split).flatten

    stops = STOPS
    stops += terms
    stops += term_words

    text = text.flatten.join(' ').downcase
    words = text.split
    @word_frequency = words.reject { |a| stops.include?(a) || a.length < 4 }.each_with_object(Hash.new(0)) { |word, counts| counts[word] += 1 }
    @phrase2_frequency = words.each_cons(2).reject { |a, b| stops.include?("#{a} #{b}") || (stops.include?(a) || stops.include?(b)) || (a.length < 4 || b.length < 4) }.each_with_object(Hash.new(0)) { |word, counts| counts[word.join(' ')] += 1 }

    @host_frequency = hosts.each_with_object(Hash.new(0)) { |key, hash| hash[key] += 1 }
    erb :'knowledgegraph/stats'
  end
end
