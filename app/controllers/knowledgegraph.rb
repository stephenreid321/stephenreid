StephenReid::App.controller do
  get '/knowledgegraph/r' do
    Post.sync_with_pocket
    redirect '/knowledgegraph?r=1'
  end

  get '/knowledgegraph', cache: true do
    expires 1.hour.to_i
    @title = 'Knowledgegraph'
    @og_desc = "Network view of posts I've shared"
    @full_network = true
    @posts = Post.all(filter: "AND(
        IS_AFTER({Created at}, '#{1.month.ago.to_s(:db)}'),
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

end
