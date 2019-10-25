class BlogPost < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Blog posts"        
  
  def post
    Post.all(filter: "{Link} = 'https://stephenreid.net/blog/#{self['Slug']}'").first
  end
  
end