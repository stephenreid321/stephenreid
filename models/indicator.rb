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
  
  def correct?
    timestamps = Indicator.order('timestamp asc').pluck(:timestamp).uniq
    i = timestamps.index(timestamp)
    price = Indicator.find_by(timestamp: timestamps[i], name: 'price').value.to_f
    if price_indicator_next = Indicator.find_by(timestamp: timestamps[i+1], name: 'price')
      price_next = price_indicator_next.value.to_f
      case value
      when 'Buy'      
        price_next > price
      when 'Sell'
        price_next < price
      end
    end
  end
    
end
