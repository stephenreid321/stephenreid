StephenReid::App.helpers do
  def timeago(x)
    %(<abbr data-toggle="tooltip" class="timeago" title="#{x.iso8601}">#{x}</abbr>)
  end

  def md(slug)
    begin
      text = open("#{Padrino.root}/app/markdown/#{slug}.md").read.force_encoding('utf-8')
      text = text.gsub(/\A---(.|\n)*?---/, '')
    rescue StandardError
      text = slug
    end
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true, fenced_code_blocks: true)
    markdown.render(text)
  end

  def front_matter(slug)
    text = open("#{Padrino.root}/app/markdown/#{slug}.md").read.force_encoding('utf-8')
    FrontMatterParser::Parser.new(:md).call(text)
  end

  def cp(slug)
    cache(slug, expires: 6.hours.to_i) { ; partial :"#{slug}"; }
  end

  def current_account
    @current_account ||= Account.find(session[:account_id]) if session[:account_id]
  end

  def sign_in_required!
    halt(403) unless current_account
  end

  def tag_badge(tag)
    %(<span href="/coins/tag/#{tag.name}" class="badge badge-secondary" style="background-color: #{tag.background_color}; color: white">#{tag.name}</span>) if tag
  end
end
