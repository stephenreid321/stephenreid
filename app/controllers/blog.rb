StephenReid::App.controller do
  get '/ai/prompt' do
    BlogPost.first.prompt.join("\n\n").gsub("\n", '<br />')
  end

  get '/ai' do
    @blog_posts = BlogPost.all.order_by('created_at desc')
    render :'blog/index'
  end

  post '/ai' do
    @blog_post = BlogPost.create(title: params[:title])
    redirect "#{@blog_post.url}?refresh_image=1"
  end

  get '/ai/:slug' do
    @blog_post = BlogPost.find_by(slug: params[:slug]) || not_found
    @title = @blog_post.title
    @og_image = @blog_post.image_url
    render :'blog/post'
  end

  post '/ai/:slug/image_word' do
    @blog_post = BlogPost.find_by(slug: params[:slug]) || not_found
    @blog_post.image_word = params[:image_word]
    @blog_post.set_image
    @blog_post.save
    redirect "#{@blog_post.url}?refresh_image=1"
  end

  get '/ai/:slug/refresh_image' do
    @blog_post = BlogPost.find_by(slug: params[:slug]) || not_found
    @blog_post.set_image
    @blog_post.save
    redirect "#{@blog_post.url}?refresh_image=1"
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
