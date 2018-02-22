class TarotSuit
  include Mongoid::Document
  include Mongoid::Timestamps

  field :suit, :type => String
  field :keywords, :type => String
  field :teachmetarot_url, :type => String
  
  has_many :tarot_cards, :dependent => :destroy
  
  def self.admin_fields
    {
      :suit => :text,
      :keywords => :text_area,
      :teachmetarot_url => :url,
      :tarot_cards => :collection
    }
  end
  
  def self.suits
    %w{wands pentacles cups swords}
  end
  
  def self.import
    a = Mechanize.new    
    suits.each { |suit|      
      slugs = [
        "the-suit-of-#{suit}",
        "the-suitof-#{suit}",
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
      
      TarotSuit.create suit: suit, keywords: a.get(page).search('.entry p').first.text, teachmetarot_url: "https://teachmetarot.com/#{slug}/"
    }    
  end
    
end
