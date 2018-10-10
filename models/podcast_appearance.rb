class PodcastAppearance
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model    

  field :title, :type => String
  field :url, :type => String
  
  belongs_to :organisation
  
  validates_uniqueness_of :url
         
  def self.admin_fields
    {
      :title => :text,
      :url => :url,
      :organisation_id => :lookup
    }
  end      
  
end
