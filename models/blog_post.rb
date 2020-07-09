class BlogPost < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Blog posts"        
  
  def post
    Post.all(filter: "{Link} = 'https://stephenreid.net/blog/#{self['Slug']}'").first
  end
  
  def self.load!
    
    Nokogiri::HTML.parse(open('https://keybase.pub/stephenreid321/stephenreid.net/blog/').read).search('.directory a.file').each { |f|
      slug, ext = f.text.split('.')
      if !BlogPost.all(filter: "{Slug} = '#{slug}'").first
        blog_post = BlogPost.new('Slug' => slug)
        url = "https://stephenreid321.keybase.pub/stephenreid.net/blog/#{slug}.md"
        text = open(url).read.force_encoding('utf-8')      
        YAML.load(text).each { |k,v|
          blog_post[k] = v
          blog_post.save
        }
      end
    }
    
  end
  
end