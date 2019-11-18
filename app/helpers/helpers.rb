ActivateApp::App.helpers do
    
  def timeago(x)
    %Q{<abbr class="timeago" title="#{x.iso8601}">#{x}</abbr>}
  end  
  
  def md(text)
    if text.starts_with?('http')
      text = open(text).read.force_encoding('utf-8')
    end
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    markdown.render(text)      
  end
  
  def cp(slug)
    cache(slug, :expires => 6.hours.to_i) do; partial :"#{slug}"; end
  end
         
end