
namespace :crypto do
  
  task :enter_or_exit => :environment do
   
    page = Mechanize.new.get('http://selenium321.herokuapp.com/visit?url=https://uk.tradingview.com/symbols/BTCUSD/technicals/')

    signals = {}
    page.search('#technicals-root table')[0..1].search('tr[class^=row]').each { |row|
      signals[row.search('td')[0].text] = row.search('td')[2].text
    }
    signals

    statuses = ['Strong Buy', 'Buy', 'Neutral', 'Sell',  'Strong Sell']
    raise 'unknown signal' unless signals.values.all? { |v| statuses.include?(v) }

    results = signals.values.each_with_object(Hash.new(0)){|key,hash| hash[key] += 1}

    score = (results['Strong Buy'] * 2) + (results['Buy'] * 1) + (results['Sell'] * -1) + (results['Strong Sell'] * -2)

    mail = Mail.new
    mail.to = 'stephen@stephenreid.net'
    mail.from = 'crypto@stephenreid.net'
    mail.subject = "Score: #{score}"
    mail.body = results.map { |k,v| "#{k}: #{v}" }.join("\n") + "\n\n" + signals.map { |k,v| "#{k}: #{v}" }.join("\n")
    mail.deliver     
    
    if score >= 0
      MyBinance.enter             
    else
      MyBinance.exit
    end    
    
  end
end