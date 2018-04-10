class Podcast
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model    

  field :name, :type => String
  field :url, :type => String  
  field :image_uid, :type => String
  
  validates_presence_of :name
        
  def self.admin_fields
    {
      :name => :text,
      :url => :url,
      :image_url => :text,
      :image => :image,
    }
  end
    
end
