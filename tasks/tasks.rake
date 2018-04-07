
namespace :crypto do
  
  task :indicators => :environment do
   
    url = 'https://uk.tradingview.com/symbols/BTCUSD/technicals/'
    cmd = %Q{page.all('#technicals-root div').detect { |div| div.text == '1 hour' }.click and sleep 1}
    page = Mechanize.new.get("http://selenium321.herokuapp.com/visit?url=#{URI::encode(url)}&cmd=#{URI::encode(cmd)}")

    signals = {}    
    oscillators = {}
    moving_averages = {}
    page.search('#technicals-root table')[0].search('tr[class^=row]').each { |row|
      oscillators[row.search('td')[0].text] = row.search('td')[2].text
    }
    page.search('#technicals-root table')[1].search('tr[class^=row]').each { |row|
      moving_averages[row.search('td')[0].text] = row.search('td')[2].text
    }    
    signals = oscillators.merge(moving_averages)
    statuses = ['Buy', 'Neutral', 'Sell']
    raise 'unknown signal value' unless signals.values.all? { |v| statuses.include?(v) }    
    timestamp = Time.now
    signals.each { |name,value|
      Indicator.create symbol: 'BTCUSD', name: name, value: value, timestamp: timestamp
    }    
    Indicator.create symbol: 'BTCUSD', name: 'price', value: MyBinance.usd_per_asset('BTC'), timestamp: timestamp

#    featured_signals = oscillators    
#    results = featured_signals.values.each_with_object(Hash.new(0)){|key,hash| hash[key] += 1}
#    score = (results['Buy'] * 1) + (results['Sell'] * -1)
    
#    action = 'no action'
#    status = MyBinance.balances.detect { |balance| balance['asset'] == 'BTC' } ? 'in' : 'out'
#    orders = []
#    if score >= 1 # build in a little inertia in light of the trading fee
#      if status == 'in'
#        action = 'remain in'
#      else
#        orders = MyBinance.enter
#        action = 'entered'
#      end            
#    else score <= -1
#      if status == 'out'
#        action = 'remain out'
#      else
#        orders = MyBinance.exit
#        action = 'exited'
#      end
#    end  
    
#    On 15:40 on 6th April 2018, the portfolio value was $45,000 and the BTC price was $6576    
#    usd_ref = 45000
#    usd_per_btc_ref = 6576
#    btc_ref = usd_ref.to_f/usd_per_btc_ref
#    hold = btc_ref*MyBinance.usd_per_asset('BTC')
#    p = (((MyBinance.usd_value_sum/hold) - 1)*100).round(2)
    
#    mail = Mail.new
#    mail.to = 'stephen@stephenreid.net'
#    mail.from = 'crypto@stephenreid.net'
#    mail.subject = "#{action.upcase} at #{MyBinance.usd_per_asset('BTC')} #{p}%"
#    mail.body = "#{url}\n#{cmd}\n\n#{orders}\n\nScore: #{score}\n\n" + results.map { |k,v| "#{k}: #{v}" }.join("\n") + "\n\n" + featured_signals.map { |k,v| "#{k}: #{v}" }.join("\n")
#    mail.deliver        
    
  end
end