class TarotCard < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Tarot cards'

  belongs_to :tarot_suit, class: 'TarotSuit', column: 'Tarot suit'
  belongs_to :tarot_number, class: 'TarotNumber', column: 'Tarot number'

  def update_image
    agent = Mechanize.new
    page = agent.get('https://blog.goo.ne.jp/valet_de_coupe/e/cb9361a10db2c819ee498cf250f66813')
    srcs = page.search('.entry-body img').map { |img| img.parent.attr('href') }
    srcs.delete_at(1)
    suits = %w[wands cups swords pentacles]
    offset = tarot_suit ? (21 + (suits.index(tarot_suit['Name']) * 14)) : 0
    self['Image'] = [{ url: srcs[offset + tarot_number['Value']] }]
    save
  end
end
