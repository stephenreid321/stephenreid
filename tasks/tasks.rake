
namespace :crypto do
  
  task :enter_or_exit => :environment do
   
    url = 'https://uk.tradingview.com/symbols/BTCUSD/technicals/'
    cmd = %Q{page.all('#technicals-root div').detect { |div| div.text == '1 hour' }.click and sleep 1}
    page = Mechanize.new.get("http://selenium321.herokuapp.com/visit?url=#{URI::encode(url)}&cmd=#{URI::encode(cmd)}")

    signals = {}
    page.search('#technicals-root table')[0..1].search('tr[class^=row]').each { |row|
      signals[row.search('td')[0].text] = row.search('td')[2].text
    }
    signals

    statuses = ['Strong Buy', 'Buy', 'Neutral', 'Sell',  'Strong Sell']
    raise 'unknown signal value' unless signals.values.all? { |v| statuses.include?(v) }

    results = signals.values.each_with_object(Hash.new(0)){|key,hash| hash[key] += 1}

    score = (results['Strong Buy'] * 2) + (results['Buy'] * 1) + (results['Sell'] * -1) + (results['Strong Sell'] * -2)
    
    action = 'no action'
    f = Fragment.find_by(slug: 'crypto-status')
    if score >= 1 # build in a little inertia in light of the trading fee
      if f.body == 'exited'
        MyBinance.enter    
        action = 'entered'        
        f.set(body: action)
      end
    else score <= -1
      if f.body == 'entered'
        MyBinance.exit
        action = 'exited'
        f.set(body: action)
      end
    end  
    
    hold = 7.51*MyBinance.usd_per_asset('BTC')
    p = (((MyBinance.usd_value_sum/hold)*100) - 100).round(2)    
    
    mail = Mail.new
    mail.to = 'stephen@stephenreid.net'
    mail.from = 'crypto@stephenreid.net'
    mail.subject = "#{action.upcase} at #{MyBinance.usd_per_asset('BTC')} #{p}%"
    mail.body = "#{url}\n#{cmd}\n\nScore: #{score}\n\n" + results.map { |k,v| "#{k}: #{v}" }.join("\n") + "\n\n" + signals.map { |k,v| "#{k}: #{v}" }.join("\n")
    mail.deliver        
    
  end
end