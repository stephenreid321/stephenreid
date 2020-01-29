class Group < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Groups"        
end