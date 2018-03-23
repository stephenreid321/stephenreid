
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
    
    action = nil
    f = Fragment.find_by(slug: 'crypto-status')
    if score >= 0
      if f.body == 'exited'
        MyBinance.enter                
        f.set(body: (action = 'entered'))
      end
    else
      if f.body == 'entered'
        MyBinance.exit
        f.set(body: (action = 'exited'))
      end
    end  
    
    if action
      mail = Mail.new
      mail.to = 'stephen@stephenreid.net'
      mail.from = 'crypto@stephenreid.net'
      mail.subject = "#{action.upcase} at #{MyBinance.usd_per_asset('BTC')}"
      mail.body = "#{url}\n#{cmd}\n\nScore: #{score}\n\n" + results.map { |k,v| "#{k}: #{v}" }.join("\n") + "\n\n" + signals.map { |k,v| "#{k}: #{v}" }.join("\n")
      mail.deliver        
    end
    
  end
end