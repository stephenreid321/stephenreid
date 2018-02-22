class TarotNumber
  include Mongoid::Document
  include Mongoid::Timestamps

  field :number, :type => String
  field :keywords, :type => String
  field :teachmetarot_url, :type => String
  
  has_many :tarot_cards, :dependent => :destroy
  
  def self.admin_fields
    {
      :number => :text,
      :keywords => :text_area,
      :teachmetarot_url => :url,
      :tarot_cards => :collection
    }
  end
  
  def self.numbers
    %w{zero ace two three four five six seven eight nine ten page knight queen king}
  end
  
  def self.numerals
    %w{0 i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx xxi}
  end
  
  def self.import    
    a = Mechanize.new         
    numbers.each_with_index { |n,i|    
      next if i == 0
      slugs = [
        "#{n.pluralize}-intro",
        "the-#{n.pluralize}-intro",
        "#{n.pluralize}-#{numerals[i]}-intro"
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
      
      TarotNumber.create number: n, keywords: a.get(page).search('.entry p')[1].text, teachmetarot_url: "https://teachmetarot.com/#{slug}/"        
    }    
  end
    
end
