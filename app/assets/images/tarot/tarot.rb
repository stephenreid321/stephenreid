require 'mechanize'

a = Mechanize.new
page = a.get('https://en.wikipedia.org/wiki/Rider-Waite_tarot_deck')

page.search("a[href*='File:']").each { |link|
  filepage = a.get('https://en.wikipedia.org'+link['href'])
  begin
    a.get(filepage.search('#file img')[0]['src']).save
  rescue; end
}
