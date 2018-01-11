class Holding
  include Mongoid::Document
  include Mongoid::Timestamps

  field :wallet, :type => String
  field :currency, :type => String
  field :symbol, :type => String
  field :units, :type => Float
  
  def cryptocompare
    @cryptocompare ||= JSON.parse(Mechanize.new.get("https://min-api.cryptocompare.com/data/price?fsym=#{symbol}&tsyms=USD,GBP").body)
  end
  
  def usd_per_unit    
    @cryptocompare['USD']
  end  
              
  def gbp_per_unit
    @cryptocompare['GBP']
  end  
  
  def usd_value
    (units*usd_per_unit).round
  end
  
  def gbp_value
    (units*gbp_per_unit).round
  end  
  
  validates_presence_of :wallet, :currency, :symbol, :units
        
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
