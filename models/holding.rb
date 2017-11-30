class Holding
  include Mongoid::Document
  include Mongoid::Timestamps

  field :description, :type => String
  field :currency, :type => String
  field :amount, :type => Float
    
  def btc_per_unit    
    return 1 if currency == 'bitcoin'
    Mechanize.new.get("https://www.coinmath.com/#{currency}/btc").search('.price.number-with-commas')[0].text.to_f
  end
  
  def self.usd_per_btc
    Mechanize.new.get("https://www.coinmath.com/bitcoin/usd").search('.price.number-with-commas')[0].text.to_f
  end  
  
  def usd_per_unit
    btc_per_unit * Holding.usd_per_btc
  end
  
  def valuation
    (amount*usd_per_unit).round
  end
  
  validates_presence_of :description, :currency, :amount
        
  def self.admin_fields
    {
      :description => :text,
      :currency => :text,
      :amount => :number
    }
  end
    
end
