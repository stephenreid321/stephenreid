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

  def cp(slug, locals: {}, key: slug, expires: 1.hours.to_i)
    Padrino.env == :development ? partial(slug, locals: locals) : cache(key, expires: expires) { partial(slug, locals: locals) }
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

  # Extract a JSON array value that follows `key` in an RSC payload, skipping
  # bracket characters that appear inside strings.
  def extract_json_array(body, key)
    bytes = body.b
    i = bytes.index(key.b)
    return nil unless i

    start = i + key.bytesize
    start += 1 while start < bytes.bytesize && bytes.byteslice(start, 1) =~ /\s/
    return nil unless bytes.byteslice(start, 1) == '['

    depth = 0
    in_string = false
    escape = false
    bytes.byteslice(start..).each_byte.with_index do |c, idx|
      if escape
        escape = false
        next
      end
      if in_string
        if c == 92 # backslash
          escape = true
        elsif c == 34 # double quote
          in_string = false
        end
        next
      end
      case c
      when 34 # double quote
        in_string = true
      when 91 # [
        depth += 1
      when 93 # ]
        depth -= 1
        return bytes.byteslice(start, idx + 1).force_encoding('UTF-8') if depth.zero?
      end
    end
    nil
  end
end
