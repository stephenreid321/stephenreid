class TarotCard
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  field :keywords, :type => String
  field :teachmetarot_url, :type => String
  
  belongs_to :tarot_suit, optional: true
  belongs_to :tarot_number, optional: true
  
  def self.majors
    ['fool', 'magician', 'high priestess', 'empress', 'emperor', 'lovers', 'chariot', 'strength', 'hermit', 'wheel of fortune',
      'justice', 'hanged man', 'death', 'temperance', 'devil', 'tower', 'star', 'moon', 'sun', 'judgement', 'world']
  end
  
  def self.admin_fields
    {
      :name => :text,
      :tarot_suit_id => :lookup,
      :tarot_number_id => :lookup,
      :teachmetarot_url => :url,
      :keywords => :text_area
    }
  end
  
  def self.import_majors
    a = Mechanize.new
    majors.each_with_index { |major,i|
      slugs = [
        "#{major}-#{TarotNumber.numerals[i]}-upright",
        "the-#{major}-#{TarotNumber.numerals[i]}-upright",
        "#{major}-#{TarotNumber.numerals[i]}",
        "the-#{major}-#{TarotNumber.numerals[i]}"    
      ]
      
      page = nil
      slug = nil
      slugs.each { |s|
        slug = s
        page = begin; a.get("https://teachmetarot.com/#{slug}/"); rescue; end
        if page
          # puts "found #{slug}"
          break 
        end
      }
      if !page
        puts "couldn't find #{slugs.first}"
        next
      end
        
      begin
        TarotCard.create name: major, keywords: page.search(".entry h2:contains('Keywords')").first.next.next.text, teachmetarot_url: "https://teachmetarot.com/#{slug}/"
      rescue => e
        puts "couldn't find keywords for #{major}"
        next
      end  
    }
  end
  
  def self.import_suits
    a = Mechanize.new    
    TarotSuit.suits.each { |suit|           
      TarotNumber.numbers.each_with_index { |n,i|                        
        next if i == 0
        slugs = [
          "#{n}-of-#{suit.pluralize}",
          "#{n}-#{TarotNumber.numerals[i]}-of-#{suit.pluralize}",
          "the-#{n}-#{TarotNumber.numerals[i]}-of-#{suit.pluralize}",
          "the-#{n}-of-#{suit.pluralize}",          
        ]
        
        page = nil
        slug = nil
        slugs.each { |s|
          slug = s
          page = begin; a.get("https://teachmetarot.com/#{slug}/"); rescue; end
          if page
            # puts "found #{slug}"
            break 
          end
        }
        if !page
          puts "couldn't find #{slugs.first}"
          next
        end
        
        begin
          TarotCard.create name: "the #{n} of #{suit}", tarot_suit: TarotSuit.find_by(suit: suit), tarot_number: TarotNumber.find_by(number: n), keywords: page.search(".entry h2:contains('Keywords')").first.next.next.text, teachmetarot_url: "https://teachmetarot.com/#{slug}/"
        rescue => e
          puts "couldn't find keywords for the #{n} of #{suit}: #{e}"
          next
        end
                        
      }
    }    
  end
    
end
