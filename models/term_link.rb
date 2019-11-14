class TermLink < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Term Links"    
    
  belongs_to :source, :class => 'Term', :column => 'Source'  
  belongs_to :sink, :class => 'Term', :column => 'Sink'
  
  has_many :posts, :class => 'Post', :column => 'Posts'

end