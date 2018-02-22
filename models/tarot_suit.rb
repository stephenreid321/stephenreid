class TarotSuit
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  field :keywords, :type => String
  field :teachmetarot_url, :type => String
  
  has_many :tarot_cards, :dependent => :destroy
  
  def self.admin_fields
    {
      :name => :text,
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
    suits.each { |suit_name|      
      slugs = [
        "the-suit-of-#{suit_name}",
        "the-suitof-#{suit_name}",
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
      
      TarotSuit.create name: suit_name, keywords: a.get(page).search('.entry p').first.text, teachmetarot_url: "https://teachmetarot.com/#{slug}/"
    }    
  end
    
end
