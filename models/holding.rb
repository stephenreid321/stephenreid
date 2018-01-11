class Holding
  include Mongoid::Document
  include Mongoid::Timestamps

  field :wallet, :type => String
  field :currency, :type => String
  field :symbol, :type => String
  field :units, :type => Float
  
  validates_presence_of :wallet, :currency, :symbol, :units
  
  def usd_per_unit
    @usd_per_unit ||= Mechanize.new.get("https://coinmarketcap.com/currencies/#{currency}").search('#quote_price .text-large2')[0].text.to_f
  end  
          
  def self.gbp_per_usd
    @gbp_per_usd ||= JSON.parse(Mechanize.new.get('https://api.fixer.io/latest?base=USD&symbols=GBP').body)['rates']['GBP']
  end
    
  def gbp_per_unit
    usd_per_unit * Holding.gbp_per_usd
  end  
  
  def usd_value
    (units*usd_per_unit).round
  end
  
  def gbp_value
    (units*gbp_per_unit).round
  end  
        
  def self.admin_fields
    {
      :wallet => :text,
      :currency => :text,
      :symbol => :text,
      :units => :number
    }
  end
  
  def create_snapshot
    Snapshot.create(
      :wallet => wallet,
      :currency => currency,
      :symbol => symbol,
      :units => units,
      :usd_per_unit => usd_per_unit,
      :gbp_per_unit => gbp_per_unit
    )    
  end
  
  def self.create_snapshots
    Holding.all.each { |holding|
      holding.create_snapshot
    }
  end
    
end
