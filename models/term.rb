class Term < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Terms"    
    
  belongs_to :organisation, :class => 'Organisation', :column => 'Organisation'    
  
  has_many :posts, :class => 'Post', :column => 'Posts'

  def tagify
    term = self
    posts = Post.all(filter: "
        OR(
          FIND(LOWER('#{term['Name']}'), LOWER({Title})) > 0,
          FIND(LOWER('#{term['Name']}'), LOWER({Body})) > 0,
          FIND(LOWER('#{term['Name']}'), LOWER({Iframely})) > 0
        )
      ", sort: { "Created at" => "desc" })
    posts.each { |post| puts post['Title']; post.tagify }
  end
  
end