class Metainterest < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Metainterests"       
  
  has_many :interests, :class => 'Interest', :column => 'Interests'
    
end