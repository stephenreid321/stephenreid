class MyBinance
  
  class << self
  
    def client
      @client ||= Binance::Client::REST.new api_key: ENV['BINANCE_API_KEY'], secret_key: ENV['BINANCE_API_SECRET']
    end
  
    def prices(refresh = false)
      if !@prices or refresh
        @prices = client.all_prices
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
        @balances = @balances.reject { |balance| balance['usd'] < 1 }
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
  
    def dp_for_symbol(symbol)
      info = exchange_info['symbols'].detect { |x| x['symbol'] == symbol }
      dp = info['filters'].detect { |x| x['filterType'] == 'LOT_SIZE' }['stepSize'].index('1')
      dp > 0 ? dp-1 : dp
    end
    
    def enter
      btc_per_usd = 1/usd_per_asset('BTC')
      q_btc = balances.detect { |balance| balance['asset'] == 'USDT' }['free'].to_f*btc_per_usd
      client.create_order symbol: 'BTCUSDT', side: 'BUY', type: 'MARKET', quantity: q_btc.floor(dp_for_symbol('BTCUSDT'))      
    end    
    
    def exit
      balances.each { |balance|  
        if !%w{USDT BTC}.include?(balance['asset'])
          symbol = "#{balance['asset']}BTC"
          q = balance['free'].to_f.floor(dp_for_symbol(symbol))
          client.create_order symbol: symbol, side: 'SELL', type: 'MARKET', quantity: q
        end
      } 
      balances(true)
      q = balances.detect { |balance| balance['asset'] == 'BTC' }['free'].to_f.floor(dp_for_symbol('BTCUSDT'))
      client.create_order symbol: 'BTCUSDT', side: 'SELL', type: 'MARKET', quantity: q      
    end
      
  end
end