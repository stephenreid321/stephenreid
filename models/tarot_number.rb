class TarotNumber < Airrecord::Table
  self.base_key = "app4hoAsMWepL2a7D"
  self.table_name = "Tarot numbers"
  
  has_many :tarot_cards, :class => "TarotCard", :column => "Tarot cards"
    
  def self.numbers
    %w{zero ace two three four five six seven eight nine ten page/eleven knight/twelve queen/thirteen king/fourteen fifteen sixteen seventeen eighteen nineteen twenty} + ['twenty one']
  end
  
  def self.numerals
    %w{0 i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx xxi}
  end    
    
end