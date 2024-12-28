StephenReid::App.helpers do
  def timeago(x)
    %(<abbr data-toggle="tooltip" class="timeago" title="#{x.iso8601}">#{x.iso8601}</abbr>)
  end

  def audio_prompt
    p = ['You are [Stephen Reid](https://stephenreid.net). Here is information on Stephen:']
    p += BlogPost.prompt[0..1]
    p
  end

  def md(slug, render: true)
    begin
      text = File.read("#{Padrino.root}/app/markdown/#{slug}.md").force_encoding('utf-8')
      text = text.gsub(/\A---(.|\n)*?---/, '')
    rescue StandardError
      text = slug
    end
    if render
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true, fenced_code_blocks: true)
      markdown.render(text)
    else
      text
    end
  end

  def front_matter(slug)
    text = File.read("#{Padrino.root}/app/markdown/#{slug}.md").force_encoding('utf-8')
    FrontMatterParser::Parser.new(:md).call(text)
  end

  def cp(slug, locals: {}, key: slug, expires: 1.hours.to_i)
    Padrino.env == :development ? partial(slug, locals: locals) : cache(key, expires: expires) { partial(slug, locals: locals) }
  end

  def current_account
    @current_account ||= Account.find(session[:account_id]) if session[:account_id]
  end

  def sign_in_required!
    halt(403) unless current_account
  end

  def tag_badge(tag, account: tag.try(:account), html_tag: 'a')
    return unless tag

    if tag.is_a?(Tag)
      name = tag.name
      bg = "background-color: #{tag.background_color}"
      c = ''
      s = ''
    else
      name = tag
      bg = 'background: none'
      c = 'text-contrast'
      s = 'font-weight: 500'
    end
    %(<#{html_tag} href="/u/#{account.username}/tags/#{name}" class="badge badge-secondary #{c}" style="#{bg}; #{s}">#{name}</#{html_tag}>)
  end

  def substack_posts(limit: nil)
    posts = Dir["#{Padrino.root}/app/substack/posts/*.html"]
            .sort_by { |file| file.split('/').last.split('.').first.to_i }
    posts = posts.reverse

    # Read CSV once before the filtering
    csv_posts = CSV.read("#{Padrino.root}/app/substack/posts.csv", headers: true)

    # Filter posts to only include those with 'In Correspondence' in the title
    posts = posts.select do |file|
      post_id = file.split('/').last.gsub('.html', '')
      post = csv_posts.find { |row| row['post_id'] == post_id }
      post && post['title'].include?('In Correspondence')
    end

    posts = posts[0..(limit.to_i - 1)] if limit

    posts.reverse.map do |file|
      post_id = file.split('/').last.gsub('.html', '')
      post = csv_posts.find { |row| row['post_id'] == post_id }

      doc = Nokogiri::HTML(
        "<h1>#{post['title']}, #{post['post_date']}</h1>
            #{File.read(file).gsub(/<source.*?>/, '')}"
      )
      doc.search('div.image2-inset').each do |tag|
        tag.replace(tag.children)
      end
      doc.search('picture').each do |tag|
        tag.replace(tag.children)
      end
      doc.search('div.image-link-expand').remove
      doc.search('img').each do |tag|
        tag['src'] = tag['srcset'].split(' ')[-2] if tag['srcset']
      end

      ReverseMarkdown.convert(doc.to_html.gsub('<div></div>', ''))
    end.join("\n")
  end
end
