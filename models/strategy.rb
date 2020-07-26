class Strategy < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Strategies"    
  
   
  def self.iconomi(path)
    t = DateTime.now.strftime('%Q')

    method = 'GET'
    message = t + method.upcase + path

    signature = Base64.encode64(
      OpenSSL::HMAC.digest(
        'sha512',
        ENV['ICN_SECRET'],
        message
      )
    ).split.join # to remove newlines introduced by base64 encoding

    agent = Mechanize.new
    agent.request_headers = {
      'ICN-API-KEY' => ENV['ICN_API_KEY'],
      'ICN-SIGN' => signature,
      'ICN-TIMESTAMP' => t
    }
    return agent.get('https://api.iconomi.com'+path).body   
  end
  
  def self.import
    JSON.parse(iconomi('/v1/strategies')).each { |s|
      strategy = Strategy.all(filter: "{Ticker} = '#{s['ticker']}'").first || Strategy.new(ticker: s['ticker'])
      s.each { |k,v| strategy[k] = v }
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
    j = JSON.parse(Strategy.iconomi("/v1/strategies/#{self['ticker']}"))
    %w{management performance entry exit}.each { |r|
      self["#{r}Fee"] = j["#{r}Fee"]
    }    
    j = JSON.parse(Strategy.iconomi("/v1/strategies/#{self['ticker']}/structure"))
    %w{numberOfAssets lastRebalanced monthlyRebalancedCount}.each { |r|            
      self[r] = (r == 'lastRebalanced' ? Time.at(j[r]).to_date : j[r]) 
    }
    j = JSON.parse(Strategy.iconomi("/v1/strategies/#{self['ticker']}/statistics"))
    %w{MONTH THREE_MONTH SIX_MONTH YEAR}.each { |r|
      self[r] = j['returns'][r]
    }
    self.save
  end
  
  
end