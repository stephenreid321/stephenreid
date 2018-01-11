class Price
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :symbol, :type => String
  field :usd_per_unit, :type => Float
      
  validates_presence_of :symbol, :usd_per_unit
  
  def self.symbols
    %w{XRP BTC ETH DASH DCR XMR XLM OMG SALT NEO ADA XVG}
  end
  
  def self.snap
    symbols.each { |symbol|
      Price.create(
        :symbol => symbol,
        :usd_per_unit => JSON.parse(Mechanize.new.get("https://min-api.cryptocompare.com/data/price?fsym=#{symbol}&tsyms=USD").body)['USD']
      )        
    }
  end  
        
  def self.admin_fields
    {
      :symbol => :text,
      :usd_per_unit => :number
    }
  end
    
end
