class Organisation < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Organisations"    
  
  belongs_to :interest, :class => 'Interest', :column => 'Interest'
  
  has_many :podcast_appearances, :class => 'PodcastAppearance', :column => 'Podcast appearances'
  has_many :podcast_appearances, :class => 'Podcast', :column => 'Podcasts'
  has_many :affiliations, :class => 'Affiliation', :column => 'Affiliations'
  has_many :qualifications, :class => 'Qualification', :column => 'Qualifications'
  
  def self.categories
    {
      "Key places and processes" => 'key',
      "Plans for the future" => 'future',            
      "Academic study" => 'academic',
      "Organisations I've worked with" => 'work',      
      "Communities I've spent time at" => 'communities',
      "Landscapes that have inspired me" => 'landscapes',
      "Favourite shops and restaurants" => 'shops'
    }    
  end
    
end