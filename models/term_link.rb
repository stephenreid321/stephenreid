class TermLink < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Term Links"    
    
  belongs_to :source, :class => 'Term', :column => 'Source'  
  belongs_to :sink, :class => 'Term', :column => 'Sink'
  
  has_many :posts, :class => 'Post', :column => 'Posts'
  
  def get_posts
    term_link = self
    Post.all(filter: "AND(
        FIND(', #{ term_link['Source name']},', {Terms joined}) > 0,
        FIND(', #{ term_link['Sink name']},', {Terms joined}) > 0
        )")    
  end

end