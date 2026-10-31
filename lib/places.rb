# The places on the treasure map (Google My Maps), by folder
module Places
  KML_URL = 'https://www.google.com/maps/d/kml?forcekml=1&mid=1QWAa8AYdFShGu6AgvK0ePUkgogGFEl8'.freeze
  KML_NS = { 'kml' => 'http://www.opengis.net/kml/2.2' }.freeze

  # Fetches them into data/fetched/places.json
  def self.fetch
    doc = Nokogiri::XML(Faraday.get(KML_URL).body)
    places = doc.xpath('//kml:Folder', KML_NS).map do |folder|
      {
        name: folder.at_xpath('./kml:name', KML_NS).text,
        places: folder.xpath('.//kml:Placemark', KML_NS).map do |place|
          coords = place.at_xpath('.//kml:coordinates', KML_NS).text.strip.split(',')
          { name: place.at_xpath('./kml:name', KML_NS).text, lat: coords[1], lng: coords[0] }
        end
      }
    end
    Fetched.write(:places, places)
  end
end
