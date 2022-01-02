class Podcast < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Podcasts'
end

# jQuery('.LunqxlFIupJw_Dkx6mNx').each(function() {
#   console.log('"'+jQuery('a',this).attr('title')+'","'+jQuery('span',this).text()+'","'+jQuery('a',this).attr('href')+'","'+jQuery('img',this).attr('src')+'"')
# })
