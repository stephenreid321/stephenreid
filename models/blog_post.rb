class BlogPost < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Blog posts"        
  
  def post
    Post.all(filter: "{Link} = 'https://stephenreid.net/blog/#{self['Slug']}'").first
  end
  
  def self.load!
    
    client = DropboxApi::Client.new    
    client.list_folder('/stephenreid.net/blog').entries.map(&:name).each { |f|
      slug, ext = f.split('.')
      if ext == 'md'
        if !BlogPost.all(filter: "{Slug} = '#{slug}'").first
          blog_post = BlogPost.new('Slug' => slug)
          blog_post.save        
          blog_post.update_metadata!
        end
      end
    }
    
  end
  
  def update_metadata!
    path = "blog/#{self['Slug']}.md"
    client = DropboxApi::Client.new    
    shared_link = client.list_shared_links(path: "/stephenreid.net/#{path}").links.find { |link| link.is_a?(DropboxApi::Metadata::FileLinkMetadata) }
    if !shared_link
      shared_link = client.create_shared_link_with_settings("/stephenreid.net/#{path}")
    end
    url = shared_link.url.gsub('dl=0','dl=1')
    text = open(url).read.force_encoding('utf-8')
    begin
      YAML.load(text).each { |k,v|
        self[k] = v
        self.save
      }
    rescue; end
  end
  
end