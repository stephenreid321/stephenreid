StephenReid::App.controller do
  before do
    sign_in_required!
  end

  get '/knowledgegraph/r' do
    Post.delay.sync_with_readwise
    redirect '/knowledgegraph?r=1'
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
    @post.bluesky
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
end
