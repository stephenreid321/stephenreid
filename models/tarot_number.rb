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
      
end
