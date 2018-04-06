class Indicator
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  field :value, :type => String  
          
  def self.admin_fields
    {
      :name => :text,
      :value => :text
    }
  end
    
end
