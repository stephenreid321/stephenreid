class Verse < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Tao Te Ching'

  def update_owner
    agent = Mechanize.new
    owner = agent.get("https://blockchair.com/ethereum/erc-721/token/0xbd45ce0cd50152c130e6fa09cc8501831916e36b/#{self['Token ID']}").search('.ownership-history__item a.hash').first.text
    self['Owner'] = owner
    save
  end
end
