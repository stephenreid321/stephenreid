require 'test_config'

# lib/places.rb: the places on the treasure map, by folder
class CoursesPlacesTest < ActiveSupport::TestCase
  KML = <<~XML.freeze
    <?xml version="1.0" encoding="UTF-8"?>
    <kml xmlns="http://www.opengis.net/kml/2.2">
      <Document>
        <name>Treasure map</name>
        <Folder>
          <name>Communities</name>
          <Placemark><name>Findhorn</name><Point><coordinates>
            -3.6062,57.6526,0
          </coordinates></Point></Placemark>
          <Placemark><name>Tamera</name><Point><coordinates>-8.7076,37.7208,0</coordinates></Point></Placemark>
        </Folder>
        <Folder>
          <name>Empty</name>
        </Folder>
      </Document>
    </kml>
  XML

  test "fetches the map's places into data/fetched/places.json, by folder, each where it is" do
    stub_http { |stub| stub.get(Places::KML_URL) { [200, {}, KML] } }
    places = fetched_after { Places.fetch }['places']

    assert_equal [
      { 'name' => 'Communities', 'places' => [{ 'name' => 'Findhorn', 'lat' => '57.6526', 'lng' => '-3.6062' },
                                              { 'name' => 'Tamera', 'lat' => '37.7208', 'lng' => '-8.7076' }] },
      { 'name' => 'Empty', 'places' => [] }
    ], places
  end
end
