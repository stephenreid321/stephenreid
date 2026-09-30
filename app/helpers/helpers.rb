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

  def ul_nav(items,
             prefix: '',
             ul_class: 'navbar-nav',
             li_class: 'nav-item',
             li_active_class: '',
             a_class: 'nav-link',
             a_active_class: 'active',
             ul_id: '',
             subnav_li_class: 'nav-item dropdown',
             subnav_data_toggle: 'dropdown',
             subnav_a_class: 'nav-link dropdown-toggle',
             subnav_href: 'javascript:;',
             subnav_caret: '<b class="caret"></b>',
             subnav_ul_class: 'dropdown-menu',
             subnav_ul_id: '',
             subnav_li2_class: 'nav-item',
             subnav_a2_class: 'dropdown-item',
             generate_subnav_href_and_ul: false)
    s = ''
    s << %(<ul class="#{ul_class}" id="#{ul_id}">)
    items.each do |name, path|
      if path.is_a? Array
        if generate_subnav_href_and_ul
          uuid = SecureRandom.uuid
          subnav_href = "##{uuid}"
          subnav_ul_id = uuid
        end
        s << %(<li class="#{subnav_li_class}">)
        s << %(<a data-toggle="#{subnav_data_toggle}" class="#{subnav_a_class}" href="#{subnav_href}">#{name}#{subnav_caret}</a>)
        s << ul_nav(path, prefix: prefix, ul_class: subnav_ul_class, ul_id: subnav_ul_id, li_class: subnav_li2_class,
                          li_active_class: li_active_class, a_class: subnav_a2_class, a_active_class: a_active_class)
        s << %(</li>)
      elsif path.nil?
        s << %(<li class="dropdown-divider"></li>)
      else
        path = "#{prefix}#{path}" if prefix
        s << %(<li)
        s << %( class="#{li_class} #{li_active_class if request.path == path}" )
        s << %(>)
        s << %(<a class="#{a_active_class if request.path == path} #{a_class}" href="#{path}">#{name}</a>)
        s << %(</li>)
      end
    end
    s << %(</ul>)
    s.html_safe
  end

  def fix_params!
    blanks_to_nils!(params)
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
