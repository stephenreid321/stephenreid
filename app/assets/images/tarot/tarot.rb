require 'mechanize'

a = Mechanize.new
page = a.get('https://en.wikipedia.org/wiki/Rider-Waite_tarot_deck')

page.search("a[href*='File:']").each { |link|
  filepage = a.get('https://en.wikipedia.org'+link['href'])
  begin
    a.get(filepage.search('#file img')[0]['src']).save
  rescue; end
}


TarotCard.where(:tarot_suit_id => nil).where(:image_uid => nil).each { |card|

n = TarotCard.majors.index(card.name)
puts card.name
image_url = "http://#{ENV['DOMAIN']}/images/tarot/RWS_Tarot_#{'0' if n < 10}#{n}_#{card.name.split(' ').map { |x| x.capitalize unless x == 'of' }.join('_')}.jpg"
puts image_url
card.update_attribute(:image_url, image_url)

}
