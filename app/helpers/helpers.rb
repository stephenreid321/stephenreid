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
    return if value.nil?

    n = value.to_f
    precision = n.abs >= 100 ? 0 : 2
    ActiveSupport::NumberHelper.number_to_currency(n, unit: '$', precision: precision)
  end

  def artizen_funding(row)
    sales = row[:sales].to_f
    venus = row[:venus].to_f
    match = row[:match].to_f
    prize = row[:prize].to_f
    vmp = venus + match + prize
    row.merge(
      sales: sales,
      venus: venus,
      match: match,
      prize: prize,
      vmp: vmp,
      multiple_v: (venus / sales if sales.positive?),
      multiple_ex: ((venus + match) / sales if sales.positive?),
      multiple: (vmp / sales if sales.positive?),
      raised: row[:raised].nil? ? sales + vmp : row[:raised].to_f
    )
  end

  def artizen_multiple_label(multiple)
    "#{format('%.1f', multiple)}x" unless multiple.nil?
  end

  def artizen_money_cells(row, tag: 'td')
    f = artizen_funding(row)
    [
      usd(f[:sales]), usd(f[:venus]), usd(f[:match]), usd(f[:prize]),
      usd(f[:vmp]),
      artizen_multiple_label(f[:multiple_v]), artizen_multiple_label(f[:multiple_ex]), artizen_multiple_label(f[:multiple]),
      usd(f[:raised])
    ].map { |content| %(<#{tag} class="text-right">#{content}</#{tag}>) }.join.html_safe
  end

  def artizen_heat(rows, fields)
    fields.each_with_object({}) do |field, heat|
      pairs = rows.map { |row| [row.object_id, row[field].to_f] }
      ordered = pairs.sort_by { |_, value| -value }
      ranks = {}
      last_val = nil
      last_rank = 0
      ordered.each_with_index do |(id, val), i|
        if val != last_val
          last_rank = i + 1
          last_val = val
        end
        ranks[id] = last_rank
      end
      heat[field] = ranks
    end
  end

  def artizen_heat_td(row, field, heat, total, as: :usd)
    value = row[field].to_f
    rank = heat[field][row.object_id]
    pct = artizen_rank_pct(rank, total)
    label = as == :x ? artizen_multiple_label(row[field]) : usd(value)
    note = %(<br><small class="artizen-rank">#{pct}%</small>) if pct
    %(<td class="text-right" data-order="#{value}" style="#{artizen_rank_style(pct)}">#{label}#{note}</td>).html_safe
  end

  def artizen_rank_pct(rank, total)
    return unless rank && total.to_i.positive?

    [(rank.to_f / total * 100).ceil, 1].max
  end

  def artizen_rank_style(pct)
    return 'background-color: #2DB963' if pct.nil? || pct <= 1

    t = Math.log(pct) / Math.log(100)
    r = (45 + (255 - 45) * t).round
    g = (185 + (255 - 185) * t).round
    b = (99 + (255 - 99) * t).round
    "background-color: rgb(#{r},#{g},#{b})"
  end

  def load_artizen_board
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
