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

  def admin?
    session[:admin] == true
  end

  def sign_in_required!
    halt(403) unless admin?
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

  def blanks_to_nils!(hash)
    hash.each do |k, v|
      if v.blank?
        hash[k] = nil
      elsif v.is_a? Array
        v.each_with_index { |x, i| v[i] = nil if x.blank? }.compact!
      elsif v.is_a? Hash
        blanks_to_nils!(v)
      end
    end
  end
end
