class BlogPost
  include Mongoid::Document
  include Mongoid::Timestamps

  field :title, :type => String
  field :subtitle, :type => String
  field :slug, :type => String
  field :body, :type => String 
  field :markdown, :type => Boolean, :default => false
  
  validates_presence_of :title, :slug
  validates_uniqueness_of :slug
  validates_format_of :slug, :with => /[a-z0-9\-]+/
      
  def self.admin_fields
    {
      :title => :text,
      :subtitle => :text,
      :slug => :slug,
      :markdown => :check_box,
      :body => :text_area
    }
  end
    
  before_validation :markdown_to_boolean
  def markdown_to_boolean
    self.markdown = case self.markdown
    when '1'
      true
    when '0'
      false
    else
      self.markdown
    end
    return
  end
       
end
