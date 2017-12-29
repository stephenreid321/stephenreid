class Place
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model    

  field :name, :type => String
  field :website, :type => String  
  field :image_uid, :type => String
  
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
        
  def self.admin_fields
    {
      :name => :text,
      :website => :url,
      :image_url => :text,
      :image => :image
    }
  end
    
end
