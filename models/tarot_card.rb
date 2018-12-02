class TarotCard < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Tarot cards"  
  
  belongs_to :tarot_suit, class: "TarotSuit", column: "Tarot suit"   
  belongs_to :tarot_number, class: "TarotNumber", column: "Tarot number"
      
end