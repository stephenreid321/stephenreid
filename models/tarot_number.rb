class TarotNumber
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  field :description, :type => String
  field :teachmetarot_url, :type => String
  
  has_many :tarot_cards, :dependent => :destroy
  
  def self.admin_fields
    {
      :name => :text,
      :description => :text_area,
      :teachmetarot_url => :url,
      :tarot_cards => :collection
    }
  end
  
  def self.numbers
    %w{zero ace two three four five six seven eight nine ten page/eleven knight/twelve queen/thirteen king/fourteen fifteen sixteen seventeen eighteen nineteen twenty} + ['twenty one']
  end
  
  def self.numerals
    %w{0 i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx xxi}
  end
  
  def self.import    
    a = Mechanize.new         
    numbers.each_with_index { |n,i|    
      if i > 0 and i < 15
        n_or_court_pp = n.split('/').first.parameterize.pluralize
        slugs = [
          "#{n_or_court_pp}-intro",
          "the-#{n_or_court_pp}-intro",
          "#{n_or_court_pp}-#{numerals[i]}-intro"
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
        TarotNumber.create name: n, teachmetarot_url: "https://teachmetarot.com/#{slug}/"        
      else
        TarotNumber.create name: n
      end
    }    
  end
    
end
