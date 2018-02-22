class TarotCard
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  field :description, :type => String
  field :teachmetarot_url, :type => String
  
  belongs_to :tarot_number
  belongs_to :tarot_suit, optional: true  
  
  def self.majors
    ['fool', 'magician', 'high-priestess', 'empress', 'emperor', 'hierophant', 'lovers', 'chariot', 'strength', 'hermit', 'wheel-of-fortune',
      'justice', 'hanged-man', 'death', 'temperance', 'devil', 'tower', 'star', 'moon', 'sun', 'judgement', 'world']
  end
  
  def self.admin_fields
    {
      :name => :text,
      :tarot_number_id => :lookup,
      :tarot_suit_id => :lookup,      
      :teachmetarot_url => :url,
      :description => :text_area
    }
  end
  
  def self.reimport    
    TarotSuit.delete_all
    TarotNumber.delete_all
    TarotCard.delete_all
    TarotSuit.import
    TarotNumber.import
    TarotCard.import_majors
    TarotCard.import_suits
  end
  
  def self.import_majors
    a = Mechanize.new
    majors.each_with_index { |major,i|      
      slugs = [
        "#{major}-#{TarotNumber.numerals[i]}-upright",
        "the-#{major}-#{TarotNumber.numerals[i]}-upright",
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
            
      TarotCard.create name: major, tarot_number: TarotNumber.find_by(name: TarotNumber.numbers[i]), teachmetarot_url: "https://teachmetarot.com/#{slug}/"
      
    }
  end
  
  def self.import_suits
    a = Mechanize.new    
    TarotSuit.suits.each { |suit_name|           
      TarotNumber.numbers.each_with_index { |n,i|                        
        next if i == 0 or i > 14
        n_or_court = n.split('-').first
        slugs = [
          "#{n_or_court}-of-#{suit_name.pluralize}",
          "#{n_or_court}-#{TarotNumber.numerals[i]}-of-#{suit_name.pluralize}",
          "the-#{n_or_court}-#{TarotNumber.numerals[i]}-of-#{suit_name.pluralize}",
          "the-#{n_or_court}-of-#{suit_name.pluralize}",          
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
                
        TarotCard.create name: "the #{n_or_court} of #{suit_name}", tarot_suit: TarotSuit.find_by(name: suit_name), tarot_number: TarotNumber.find_by(name: TarotNumber.numbers[i]), teachmetarot_url: "https://teachmetarot.com/#{slug}/"
                                
      }
    }    
  end
    
end
