StephenReid::App.controller do
  get '/ai/prompt' do
    BlogPost.first.prompt.join("\n\n").gsub("\n", '<br />')
  end

  get '/ai' do
    redirect '/ai/public/true' if current_account
    @blog_posts = BlogPost.where(public: true)
    @blog_posts = @blog_posts.order_by('created_at desc')
    render :'blog/index'
  end

  get '/ai/public/:public' do
    public = case params[:public]
             when 'false'
               false
             when 'nil'
               nil
             else
               true
             end
    @blog_posts = BlogPost.where(public: public)
    @blog_posts = @blog_posts.order_by('created_at desc')
    render :'blog/index'
  end

  post '/ai' do
    if current_account
      @blog_post = BlogPost.create(title: params[:title])
      redirect @blog_post.url
    else
      BlogPost.confirm(params[:title], params[:email])
      redirect '/ai/thanks'
    end
  end

  get '/ai/generate/:encrypted_title' do
    title = BlogPost.decrypt(params[:encrypted_title])
    @blog_post = BlogPost.create(title: title)
    redirect @blog_post.url
  end

  get '/ai/thanks' do
    erb :'blog/thanks'
  end

  get '/ai/:slug' do
    @blog_post = BlogPost.find_by(slug: params[:slug]) || redirect('/ai')
    @title = @blog_post.title
    @og_image = @blog_post.image_url
    render :'blog/post'
  end

  post '/ai/:slug/image_word' do
    @blog_post = BlogPost.find_by(slug: params[:slug]) || not_found
    @blog_post.image_word = params[:image_word]
    @blog_post.set_image
    @blog_post.save
    redirect @blog_post.url
  end

  get '/ai/:slug/make_public' do
    @blog_post = BlogPost.find_by(slug: params[:slug]) || not_found
    @blog_post.public = true
    @blog_post.save
    redirect back
  end

  get '/ai/:slug/make_private' do
    @blog_post = BlogPost.find_by(slug: params[:slug]) || not_found
    @blog_post.public = false
    @blog_post.save
    redirect back
  end

  get '/ai/:slug/destroy' do
    sign_in_required!
    @blog_post = BlogPost.find_by(slug: params[:slug]) || not_found
    @blog_post.destroy
    redirect '/ai'
  end

  get '/ai/:slug/refresh_image' do
    sign_in_required!
    @blog_post = BlogPost.find_by(slug: params[:slug]) || not_found
    @blog_post.set_image
    @blog_post.save
    redirect @blog_post.url
  end

  get '/blog/unplugging-from-facebook' do
    redirect '/blog/2020/07/09/unplugging-from-facebook.html'
  end

  get '/blog/feed' do
    redirect '/blog/feed.xml'
  end

  get '/blog/feed.rss' do
    redirect '/blog/feed.xml'
  end

  get '/blog/?*' do
    file_path = File.join(Padrino.root('app', 'jekyll_blog', '_site'), request.path.gsub('/blog', ''))
    file_path = File.join(Padrino.root('app', 'jekyll_blog', '_site'), 'index.html') unless file_path =~ /\.[a-z]+$/i
    not_found unless File.exist?(file_path)
    content = File.binread(file_path)
    content_type = MIME::Types.type_for(file_path).first.content_type
    if content_type == 'text/html'
      content.gsub!('assets/', '/jekyll/')
      html = Nokogiri::HTML.parse(content)
      @title = (t = html.search('.post-title').text
                t.empty? ? 'Blog' : t)
      d = html.search('.post-excerpt').text
      @og_desc = d unless d.empty?
      src = html.search('.post-header-image').attr('src').to_s
      unless src.empty?
        @og_image = src.starts_with?('/') ? "#{ENV['BASE_URI']}#{src}" : (src unless src.empty?)
      end
      erb content
    else
      send_file file_path, content_type: content_type, layout: false
    end
  end
end
