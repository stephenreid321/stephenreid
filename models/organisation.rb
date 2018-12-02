class Organisation < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Organisations"    
  
  belongs_to :interest, :class => 'Interest', :column => 'Interest'
  
  has_many :podcast_appearances, :class => 'PodcastAppearance', :column => 'Podcast appearances'
  has_many :affiliations, :class => 'Affiliation', :column => 'Affiliations'
  has_many :qualifications, :class => 'Qualification', :column => 'Qualifications'
    
end