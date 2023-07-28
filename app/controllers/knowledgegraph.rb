StephenReid::App.controller do
  get '/organisations/:id/tagify' do
    @organisation = begin; Organisation.find(params[:id]); rescue StandardError; not_found; end
    @organisation.tagify
    200
  end

  get '/posts/:id/iframely' do
    @post = begin; Post.find(params[:id]); rescue StandardError; not_found; end
    agent = Mechanize.new
    result = agent.get("https://iframe.ly/api/iframely?url=#{@post['Link'].split('#').first}&api_key=#{ENV['IFRAMELY_API_KEY']}")
    @post['Iframely'] = result.body.force_encoding('UTF-8')
    @post.save
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
    200
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
    if post_ids.length > 0
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

  ############################

  get '/knowledgegraph', cache: true do
    expires 1.hour.to_i
    @title = 'Knowledgegraph'
    @og_desc = "Network view of posts I've shared"
    @full_network = true
    @posts = Post.all(filter: "AND(
        IS_AFTER({Created at}, '#{3.months.ago.to_s(:db)}'),
        FIND('\"url\": ', {Iframely}) > 0
      )", sort: { 'Created at' => 'desc' }, paginate: false)
    erb :'knowledgegraph/knowledgegraph'
  end

  get '/search' do
    if params[:q]
      @q = params[:q]
      @q, @after = @q.split('after:') if @q.include?('after:')
      @title = @q.empty? ? "Posts since #{@after}" : @q
      @posts = Post.all(filter: "AND(
        #{%{IS_AFTER({Created at}, '#{Date.parse(@after).to_s(:db)}'),} if @after}
          OR(
            FIND(LOWER('#{@q}'), LOWER({Title})) > 0,
            FIND(LOWER('#{@q}'), LOWER({Body})) > 0,
            FIND(LOWER('#{@q}'), LOWER({Iframely})) > 0
          )
        )", sort: { 'Created at' => 'desc' })
    else
      @full_network = true
      @posts = Post.all(filter: "AND(
        IS_AFTER({Created at}, '#{1.month.ago.to_s(:db)}'),
        FIND('\"url\": ', {Iframely}) > 0
      )", sort: { 'Created at' => 'desc' }, paginate: false)
    end
    erb :'knowledgegraph/knowledgegraph'
  end

  get '/feed', provides: :rss, cache: true do
    expires 1.hour.to_i
    @posts = Post.all(filter: "AND(
        IS_AFTER({Created at}, '#{1.month.ago.to_s(:db)}'),
        FIND('\"url\": ', {Iframely}) > 0
      )", sort: { 'Created at' => 'desc' }, paginate: false)
    RSS::Maker.make('atom') do |maker|
      maker.channel.author = 'Stephen Reid'
      maker.channel.updated = Time.now.to_s
      maker.channel.about = 'http://stephenreid.net'
      maker.channel.title = 'Stephen Reid'

      @posts.each do |post|
        json = JSON.parse(post['Iframely'])
        maker.items.new_item do |item|
          item.link = post['Link']
          item.title = post['Title']
          item.description = (json['meta']['description'].truncate(150) if json['meta']['description'])
          item.updated = post['Created at']
        end
      end
    end.to_s
  end

  get '/posts/:id', cache: true do
    expires 1.hour.to_i
    @post = begin; Post.find(params[:id]); rescue StandardError; not_found; end
    @json = JSON.parse(@post['Iframely'])
    @full_title = @post['Title']
    @og_desc = @json['meta']['description']
    @og_image = @json['links']['thumbnail'].first['href'] if @json['links'] && @json['links']['thumbnail']
    erb :'knowledgegraph/post'
  end

  get '/terms/:source_id/:sink_id', cache: true do
    expires 1.hour.to_i
    @source = Term.find(params[:source_id])
    @sink = Term.find(params[:sink_id])
    @posts = Post.all(filter: "AND(
        FIND(', #{@source['Name']},', {Terms joined}) > 0,
        FIND(', #{@sink['Name']},', {Terms joined}) > 0
        )", sort: { 'Created at' => 'desc' })
    erb :'knowledgegraph/knowledgegraph'
  end

  get '/terms/:term', cache: true do
    expires 1.hour.to_i
    @posts = Post.all(filter: "FIND(', #{params[:term]},', {Terms joined}) > 0", sort: { 'Created at' => 'desc' })
    erb :'knowledgegraph/knowledgegraph'
  end

  get '/organisations/:organisation', cache: true do
    expires 1.hour.to_i
    @posts = Post.all(filter: "{Organisation} = '#{params[:organisation]}'", sort: { 'Created at' => 'desc' })
    erb :'knowledgegraph/knowledgegraph'
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
    term_words = terms.map { |term| term.split(' ') }.flatten

    stops = STOPS
    stops += terms
    stops += term_words

    text = text.flatten.join(' ').downcase
    words = text.split(' ')
    @word_frequency = words.reject { |a| stops.include?(a) || a.length < 4 }.each_with_object(Hash.new(0)) { |word, counts| counts[word] += 1 }
    @phrase2_frequency = words.each_cons(2).reject { |a, b| stops.include?("#{a} #{b}") || (stops.include?(a) || stops.include?(b)) || (a.length < 4 || b.length < 4) }.each_with_object(Hash.new(0)) { |word, counts| counts[word.join(' ')] += 1 }

    @host_frequency = hosts.each_with_object(Hash.new(0)) { |key, hash| hash[key] += 1 }
    erb :'knowledgegraph/stats'
  end
end
