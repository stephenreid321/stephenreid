class Holding
  include Mongoid::Document
  include Mongoid::Timestamps

  field :wallet, :type => String
  field :currency, :type => String
  field :amount, :type => Float
    
  def btc_per_unit    
    return 1 if currency == 'bitcoin'
    Mechanize.new.get("https://www.coingecko.com/en/coins/#{currency}").search('[data-price-btc]').attr('data-price-btc').value.to_f
  end
  
  def self.usd_per_btc
    Mechanize.new.get('https://www.coingecko.com/en/coins/bitcoin').search('[data-price-btc]').text.strip.gsub('$','').gsub(',','').to_f
  end  
  
  def self.gbp_per_usd
    JSON.parse(Mechanize.new.get('https://api.fixer.io/latest?base=USD&symbols=GBP').body)['rates']['GBP']
  end
  
  def usd_per_unit
    btc_per_unit * Holding.usd_per_btc
  end
  
  def valuation
    (amount*usd_per_unit).round
  end
  
  validates_presence_of :wallet, :currency, :amount
        
  def self.admin_fields
    {
      :wallet => :text,
      :currency => :text,
      :amount => :number
    }
  end
    
end
