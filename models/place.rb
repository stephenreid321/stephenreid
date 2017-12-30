class Place
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model    

  field :name, :type => String
  field :website, :type => String  
  field :image_uid, :type => String
  field :category, :type => String
  
  # Dragonfly
  dragonfly_accessor :image
  before_validation do
    if self.image
      begin
        self.image.format
      rescue        
        errors.add(:image, 'must be an image')
      end
    end
  end     
  
  validates_presence_of :name
  validates_uniqueness_of :name
  
  def self.categories
    {
      "Current affiliations" => 'current',
      "Key places and processes" => 'learning',
      "Academic study" => 'academic',
      "Organisations I've worked with" => 'work',      
      "Communities I've spent time at" => 'communities',
      "Landscapes that have inspired me" => 'landscapes',
      "Favourite shops and restaurants" => 'shops',
      "Other great places and processes" => 'other',
      "Plans for the future" => 'upcoming',
    }
  end
        
  def self.admin_fields
    {
      :name => :text,
      :category => :select,
      :website => :url,
      :image_url => :text,
      :image => :image
    }
  end
    
end
