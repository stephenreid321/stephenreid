class Qualification < Airrecord::Table
  self.base_key = "app4hoAsMWepL2a7D"
  self.table_name = "Qualifications"    
  
  belongs_to :organisation, class: "Organisation", column: "Organisation"
    
end