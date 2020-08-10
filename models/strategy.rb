class Strategy
  include Mongoid::Document
  include Mongoid::Timestamps
  class RoundingError < StandardError; end
  
  field :ticker, :type => String
  field :name, :type => String
  field :score, :type => Float
  field :score_fee_weighted, :type => Float
  field :manager, :type => String
  field :managementType, :type => String
  %w{management performance entry exit}.each { |r|
    field :"#{r}Fee", :type => Float
  }
  field :numberOfAssets, :type => Integer
  field :lastRebalanced, :type => Time
  field :monthlyRebalancedCount, :type => Integer
  %w{MONTH THREE_MONTH SIX_MONTH YEAR}.each { |r|
    field :"#{r.downcase}", :type => Float
  }
  
  validates_presence_of :ticker
  
  def calculate_score
    ((month || 0) + (three_month || 0) + (six_month || 0) + (year || 0))
  end
  
  def calculate_score_fee_weighted
    score*(1-(managementFee || 0))*(1-(performanceFee || 0))*(1-(entryFee || 0))*(1-(exitFee || 0))    
  end  

  before_validation do
    self.score = calculate_score
    self.score_fee_weighted = calculate_score_fee_weighted
  end
  
  def self.admin_fields
    {
      :ticker => :text,
      :name => :text,
      :score => :number,
      :score_fee_weighted => :number,
      :manager => :text,
      :managementType => :text,
      :managementFee => :number,
      :performanceFee => :number,
      :entryFee => :number,
      :exitFee => :number,
      :numberOfAssets => :number,
      :lastRebalanced => :datetime,
      :monthlyRebalancedCount => :number,
      :month => :number,
      :three_month => :number,
      :six_month => :number,
      :year => :number,
      :holdings => :collection
    } 
  end
  
  has_many :holdings, :dependent => :destroy
    
  def self.import
    JSON.parse(Iconomi.get('/v1/strategies')).each { |s|
      strategy = Strategy.find_or_create_by(ticker: s['ticker'])      
      %w{ticker name manager managementType}.each { |r|
        strategy.send("#{r}=", s[r])
      }
      strategy.save
    }
  end
  
  def self.update
    Strategy.all.each { |strategy|
      puts strategy['ticker']
      strategy.update
    }
  end
  
  def update    
    j = JSON.parse(Iconomi.get("/v1/strategies/#{self.ticker}"))
    %w{management performance entry exit}.each { |r|
      self.send("#{r}Fee=", j["#{r}Fee"])
    }    
    j = JSON.parse(Iconomi.get("/v1/strategies/#{self.ticker}/structure"))
    %w{numberOfAssets lastRebalanced monthlyRebalancedCount}.each { |r|            
      self.send("#{r}=", (r == 'lastRebalanced' ? Time.at(j[r]).to_date : j[r]))
    }
    holdings.destroy_all
    j['values'].each { |v|      
      asset = Asset.find_or_create_by(ticker: (v['assetTicker'] unless v['assetTicker'].blank?))
      if asset.persisted?
        asset.update_attribute(:name, v['assetName'])        
        holdings.create(:asset => asset, :weight => v['rebalancedWeight'])
      end
    }
    j = JSON.parse(Iconomi.get("/v1/strategies/#{self.ticker}/statistics"))
    %w{MONTH THREE_MONTH SIX_MONTH YEAR}.each { |r|
      self.send("#{r.downcase}=", j['returns'][r])
    }
    self.save
  end
  
  def self.mature_period
    'SIX_MONTH'
  end
  
  def self.active_mature(fee_weighted: false)
    where(:monthlyRebalancedCount.gte => 1, :"#{mature_period.downcase}".ne => nil).order(fee_weighted ? 'score_fee_weighted desc' : 'score desc')
  end
  
  def self.proposed(n, min_btc_eth: false)
    
    assets = {}
    Strategy.active_mature.each { |strategy|
      strategy.holdings.each { |holding|
        ticker = holding.asset.ticker
        assets[ticker] = 0 if !assets[ticker]
        assets[ticker] += holding.weight * strategy.score
      }
    }
    
    if min_btc_eth
      assets = assets.reject { |k,v| %w{BTC ETH}.include?(k) }
    end
    
    assets = assets.sort_by { |k,v| -v }[0..(n-1)]
    total = assets.map { |k,v| v }.sum
    assets = assets.map { |k,v| [k, v/total] }
    assets = assets.map { |k,v| [k, v] }
    
    if min_btc_eth
      assets = assets.map { |k,v| [k, (v*0.9).floor(4)] }
      t = assets.map { |k,v| v }.sum
      assets = assets + [['ETH', (1 - t).round(4)]]
    end
    
    t = assets.map { |k,v| v }.sum
    
    begin
      raise Strategy::RoundingError unless t == 1
    rescue => e
      Airbrake.notify(e)      
      raise e
    end
    
    assets
  end
  
  def self.set(n)
    
    success = nil
    until success
      
      data = {
        ticker: 'DECENTCOOP',
        values: Strategy.proposed(n, min_btc_eth: true).map { |ticker, p|
          { assetTicker: ticker, rebalancedWeight: p }
        },
        speedType: 'MEDIUM'
      }
    
      puts n
      puts data.to_json
      begin
        Iconomi.post('/v1/strategies/DECENTCOOP/structure', data.to_json)
        success = true
      rescue
        n = n - 1
      end
    end
    
  end
  
  
end