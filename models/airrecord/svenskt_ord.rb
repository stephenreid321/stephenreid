class SvensktOrd < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Svenska ord'
end

# x = ''; $('.thing').each(function() { x += $('.col_a', this).text() + "\t" + $('.col_b', this).text() + "\n" }); copy(x)
