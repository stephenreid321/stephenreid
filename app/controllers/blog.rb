StephenReid::App.controller do
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
