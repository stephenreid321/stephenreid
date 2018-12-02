class TarotSuit < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Tarot suits"     
  
  has_many :tarot_cards, :class => 'TarotCard', :column => 'Tarot cards'
    
  def self.suits
    %w{swords wands cups pentacles}
  end
  
  def self.icons
    {:swords => ['air', :cloud], :wands => ['fire', :fire], :cups => ['water', :tint], :pentacles => ['earth', :globe]}
  end 
    
end