class Indicator
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  field :value, :type => String  
  field :step, :type => Integer
          
  def self.admin_fields
    {
      :name => :text,
      :value => :text,
      :step => :number
    }
  end
    
end
