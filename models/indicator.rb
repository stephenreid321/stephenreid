class Indicator
  include Mongoid::Document
  include Mongoid::Timestamps

  field :symbol, :type => String  
  field :name, :type => String
  field :value, :type => String  
  field :timestamp, :type => Time
          
  def self.admin_fields
    {
      :symbol => :text,
      :name => :text,
      :value => :text,
      :timestamp => :datetime
    }
  end
    
end
