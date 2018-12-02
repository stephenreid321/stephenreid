class Interest < Airrecord::Table
  self.base_key = "app4hoAsMWepL2a7D"
  self.table_name = "Interests"
  
  belongs_to :metainterest, class: "Metainterest", column: "Metainterest"
    
end