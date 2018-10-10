class Organisation
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model    

  field :name, :type => String
  field :facebook_name, :type => String
  field :facebook_username, :type => String
  field :website, :type => String 
  field :podcast, :type => Boolean
  field :image_uid, :type => String
  field :category, :type => String
  field :notes, :type => String
  field :coordinates, :type => Array
  
  has_many :podcast_appearances, :dependent => :destroy
  
  def lat; coordinates[1] if coordinates; end  
  def lng; coordinates[0] if coordinates; end  
  def self.marker_color; 'CE2828'; end    
  
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
      "" => '',
      "Plans for the future" => 'upcoming',      
      "Key places and processes" => 'key',
      "Academic study" => 'academic',
      "Organisations I've worked with" => 'work',      
      "Communities I've spent time at" => 'communities',
      "Landscapes that have inspired me" => 'landscapes',
      "Favourite shops and restaurants" => 'shops'
    }
  end
        
  def self.admin_fields
    {
      :name => :text,
      :facebook_name => :text,
      :facebook_username => :text,
      :website => :url,    
      :category => :select,
      :podcast => :check_box,    
      :image_url => :text,
      :image => :image,
      :coordinates => :geopicker,
      :notes => :text_area,      
    }
  end
      
  def facebook_url
    "http://facebook.com/#{facebook_username}" if facebook_username
  end
  
end
