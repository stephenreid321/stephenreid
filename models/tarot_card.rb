class TarotCard < Airrecord::Table
  self.base_key = "app4hoAsMWepL2a7D"
  self.table_name = "Tarot cards"  
  
  belongs_to :tarot_suit, class: "TarotSuit", column: "Tarot suit"   
  belongs_to :tarot_number, class: "TarotNumber", column: "Tarot number"
      
end