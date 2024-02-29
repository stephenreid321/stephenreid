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
end
