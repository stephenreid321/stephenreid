class Preview
  include Mongoid::Document
  include Mongoid::Timestamps

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
  
  before_save do
    self.image_url = "http://selenium321.herokuapp.com/visit.png?url=#{url}"
  end
    
end
