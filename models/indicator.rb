class Indicator
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  field :value, :type => String  
  field :timestamp, :type => Time
          
  def self.admin_fields
    {
      :name => :text,
      :value => :text,
      :timestamp => :datetime
    }
  end
    
end
