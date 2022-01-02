class DiscordServer < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Discord servers'
end

# jQuery('[data-list-item-id^=guildsnav]').each(function() {
#
#   name = jQuery(this).attr('aria-label')
#   parts = name.split(', ')
#   name = parts[parts.length - 1]
#   href = jQuery(this).attr('href') || ''
#   parts = href.split('/')
#   id = parts[parts.length-2]
#   src = jQuery(this).find('img').attr('src')
#   console.log(name.trim() + ',' + id + ',' + src)
#
# })
