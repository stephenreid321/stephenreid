class Holding
  include Mongoid::Document
  include Mongoid::Timestamps

  field :currency, :type => String
  field :amount, :type => Float
  
  def gbp_per_unit
    Mechanize.new.get("https://www.coinmath.com/#{currency}/gbp").search('.price.number-with-commas')[0].text.to_f
  end
  
  def valuation
    (amount*gbp_per_unit).round
  end
  
  validates_presence_of :currency, :amount
        
  def self.admin_fields
    {
      :currency => :text,
      :amount => :number
    }
  end
    
end
