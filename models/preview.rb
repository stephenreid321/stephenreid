class Preview
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model    

  field :url, :type => String
  field :image_uid, :type => String
  
  validates_presence_of :url  
  dragonfly_accessor :image
        
  def self.admin_fields
    {
      :url => :url,
      :image_url => :text,
      :image => :image,
    }
  end
      
end
