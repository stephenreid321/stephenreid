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
  
  def self.gbp_per_btc
    Mechanize.new.get("http://bittybot.co/uk/sell-bitcoins-uk/").search('#bb-tablepress-sell tr')[10].search('td')[4].text.gsub('£','').gsub(',','').to_f
  end  
  
  def gbp_per_unit
    btc_per_unit * Holding.gbp_per_btc
  end
  
  def valuation
    (amount*gbp_per_unit).round
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
