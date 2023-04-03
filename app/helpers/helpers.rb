StephenReid::App.helpers do
  def timeago(x)
    %(<abbr data-toggle="tooltip" class="timeago" title="#{x.iso8601}">#{x.iso8601}</abbr>)
  end

  def audio_prompt(text)
    p = ['You are Stephen Reid. Here is information on Stephen:']
    p += BlogPost.prompt[0..1]
    p += ["---
      Now, reply to the message below in {curly brackets} as if you were Stephen.
      Reply in the first person, not the third person.
      Do not start the reply with 'hi', 'hello', or any other greeting.
      Do not start with 'Stephen' or 'Stephen Reid'.
      {#{text}}"]
    p
  end

  def md(slug, render: true)
    begin
      text = open("#{Padrino.root}/app/markdown/#{slug}.md").read.force_encoding('utf-8')
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
    text = open("#{Padrino.root}/app/markdown/#{slug}.md").read.force_encoding('utf-8')
    FrontMatterParser::Parser.new(:md).call(text)
  end

  def cp(slug, key: slug, expires: 1.hours.to_i)
    Padrino.env == :development ? partial(slug) : cache(key, expires: expires) { partial slug }
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
