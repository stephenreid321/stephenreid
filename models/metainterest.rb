class Metainterest < Airrecord::Table
  self.base_key = "app4hoAsMWepL2a7D"
  self.table_name = "Metainterests"       
  
  has_many :interests, class: "Interest", column: "Interests"
    
end