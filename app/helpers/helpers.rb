StephenReid::App.helpers do
  def timeago(x)
    %(<abbr data-toggle="tooltip" class="timeago" title="#{x.iso8601}">#{x.iso8601}</abbr>)
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

  def current_account
    @current_account ||= Account.find(session[:account_id]) if session[:account_id]
  end

  def sign_in_required!
    halt(403) unless current_account
  end

  def bool_badge(value, yes_text: 'Yes', no_text: 'No')
    if value
      %(<span class="badge badge-success">#{yes_text}</span>)
    else
      %(<span class="badge badge-secondary">#{no_text}</span>)
    end
  end

  def display_or_dash(value, format: nil, prefix: nil, suffix: nil, &block)
    if value
      formatted = if block
                    yield(value)
                  else
                    (format ? format(format, value) : value)
                  end
      result = prefix.to_s + formatted.to_s
      result += %( <small class="text-muted">#{suffix}</small>) if suffix
      result
    else
      %(<span class="text-muted">—</span>)
    end
  end

  def usd(value)
    return %(<span class="text-muted">—</span>) if value.nil?

    n = value.to_f
    precision = n.abs >= 100 ? 0 : 2
    ActiveSupport::NumberHelper.number_to_currency(n, unit: '$', precision: precision)
  end

  def load_artizen_board
    @container_class = 'container-fluid'
    @og_desc = 'Fund and project leaderboards from Artizen'
    @data = Artizen.leaderboard(season_number: params[:season])
    @seasons = @data[:seasons]
    @season = @data[:season]
    @drives = @data[:drives] || []
    @projects = @data[:projects]
    @funds = @data[:funds]
    @artizen_error = @data[:error]
    @title = @season ? "Artizen · #{@season[:title]}" : 'Artizen'
  end
end
