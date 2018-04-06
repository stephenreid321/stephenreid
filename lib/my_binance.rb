class MyBinance
  
  class << self
  
    def client
      @client ||= Binance::Client::REST.new api_key: ENV['BINANCE_API_KEY'], secret_key: ENV['BINANCE_API_SECRET']
    end
    
    def refresh
      prices(true)
      exchange_info(true)
      balances(true)
      gbp_per_usd(true)
    end
  
    def prices(refresh = false)
      if !@prices or refresh
        @prices = client.price
      else
        @prices
      end
    end
    
    def exchange_info(refresh = false)
      if !@exchange_info or refresh
        @exchange_info = client.exchange_info
      else
        @exchange_info
      end
    end
    
    def balances(refresh = false)
      if !@balances or refresh
        @balances = client.account_info['balances']
        @balances = @balances.select { |balance| balance['free'].to_f > 0 }
        @balances.each_with_index { |balance, i|
          @balances[i]['usd'] = balance['free'].to_f*usd_per_asset(balance['asset'])
        }
        @balances = @balances.reject { |balance| balance['usd'] < 100 }
        @balances = @balances.sort_by { |balance| -balance['usd'] }      
      else
        @balances
      end
    end
        
    def gbp_per_usd(refresh = false)
      if !@gbp_per_usd or refresh
        @gbp_per_usd = JSON.parse(Mechanize.new.get('https://api.fixer.io/latest?base=USD&symbols=GBP').body)['rates']['GBP']
      else 
        @gbp_per_usd
      end        
    end
    
    def usd_value_sum
      balances.map { |balance| balance['usd'] }.sum
    end
    
    def gbp_value_sum
      balances.map { |balance| balance['usd']*gbp_per_usd }.sum     
    end
    
    def usd_per_asset(asset)
      case asset
      when 'USDT'
        1
      when 'BTC'
        prices.detect { |x| x['symbol'] == "BTCUSDT" }['price'].to_f
      else
        prices.detect { |x| x['symbol'] == "#{asset}BTC" }['price'].to_f * prices.detect { |x| x['symbol'] == "BTCUSDT" }['price'].to_f
      end
    end
      
    def step_size(symbol)
      info = exchange_info['symbols'].detect { |x| x['symbol'] == symbol }
      info['filters'].detect { |x| x['filterType'] == 'LOT_SIZE' }['stepSize'] # string
    end
    
    def dp(symbol)
      dp = step_size(symbol).index('1')
      dp > 0 ? dp-1 : dp
    end    
    
    def enter   
      refresh
      orders = []
      q_usd = balances.detect { |balance| balance['asset'] == 'USDT' }['free'].to_f
      asset_weights = {'BTC' => 1} # the pair XXXUSDT must exist on Binance
      asset_weights.each { |asset, weight|
        symbol = "#{asset}USDT"
        q = (q_usd/usd_per_asset(asset))*weight
        puts "buying #{symbol} #{q}"
        order = client.create_order! symbol: symbol, side: 'BUY', type: 'MARKET', quantity: q.round(dp(symbol))
        while order['code'] == -2010 do
          q = q*0.9999 # Try 99.99% of previous figure
          order = client.create_order! symbol: symbol, side: 'BUY', type: 'MARKET', quantity: q.round(dp(symbol))
        end
        orders << order
      }
      orders
    end    
    
    def exit
      refresh
      orders = []
      balances.each { |balance| 
        if balance['asset'] != 'USDT'
          symbol = "#{balance['asset']}USDT" # the pair XXXUSDT must exist on Binance          
          q = balance['free'].to_f.floor(dp(symbol))
          puts "selling #{symbol} #{q}"
          order = client.create_order! symbol: symbol, side: 'SELL', type: 'MARKET', quantity: q
          orders << order
        end
      }
      orders
    end
      
  end
end