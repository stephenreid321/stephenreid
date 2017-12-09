class Holding
  include Mongoid::Document
  include Mongoid::Timestamps

  field :wallet, :type => String
  field :currency, :type => String
  field :units, :type => Float
    
  def btc_per_unit
    @btc_per_unit ||= Mechanize.new.get("https://coinmarketcap.com/currencies/#{currency}/").search('.text-gray.details-text-medium')[0].text.split(' ').first.to_f
    # @btc_per_unit ||= Mechanize.new.get("https://www.coinmath.com/#{currency}/btc").search('.price.number-with-commas')[0].text.to_f
  end
  
  def self.usd_per_btc
    @usd_per_btc ||= Mechanize.new.get("https://www.coinmath.com/bitcoin/usd").search('.price.number-with-commas')[0].text.to_f
  end  
     
  def self.gbp_per_usd
    @gbp_per_usd ||= JSON.parse(Mechanize.new.get('https://api.fixer.io/latest?base=USD&symbols=GBP').body)['rates']['GBP']
  end
  
  def usd_per_unit
    btc_per_unit * Holding.usd_per_btc
  end
  
  def valuation
    (units*usd_per_unit).round
  end
  
  validates_presence_of :wallet, :currency, :units
        
  def self.admin_fields
    {
      :wallet => :text,
      :currency => :text,
      :units => :number
    }
  end
    
end
