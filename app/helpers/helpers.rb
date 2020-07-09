ActivateApp::App.helpers do
    
  def timeago(x)
    %Q{<abbr class="timeago" title="#{x.iso8601}">#{x}</abbr>}
  end  
  
  def md(path)
    client = DropboxApi::Client.new
    shared_link = client.list_shared_links(path: "/stephenreid.net/#{path}").links.find { |link| link.is_a?(DropboxApi::Metadata::FileLinkMetadata) }
    if !shared_link
      shared_link = client.create_shared_link_with_settings("/stephenreid.net/#{path}")
    end
    url = shared_link.url.gsub('dl=0','dl=1')
    text = open(url).read.force_encoding('utf-8')
    text = text.gsub(/\A---(.|\n)*?---/,'')
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    markdown.render(text)      
  end
  
  def cp(slug)
    cache(slug, :expires => 6.hours.to_i) do; partial :"#{slug}"; end
  end
         
end