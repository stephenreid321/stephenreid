class Podcast < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Podcasts"    
  
  belongs_to :organisation, :class => 'Organisation', :column => 'Organisation'
    
end