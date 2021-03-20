class Verse < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Tao Te Ching'

  def set_owner
    agent = Mechanize.new
    owner = agent.get("https://opensea.io/assets/0xbd45ce0cd50152c130e6fa09cc8501831916e36b/#{self['Token ID']}").search('.item--counts a').first.attr('href').split('/').last
    self['Owner'] = owner
    save
  end
end
