class Film < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Films'

  def self.iframely
    agent = Mechanize.new
    Film.all(filter: "AND({Images} = '')").each do |film|
      result = agent.get("https://iframe.ly/api/iframely?url=#{URI.encode_www_form_component(film['URL'])}&api_key=#{ENV['IFRAMELY_API_KEY']}")
      json = JSON.parse(result.body.force_encoding('UTF-8'))
      film['Images'] = [{ url: json['links']['thumbnail'].first['href'] }] if json['links']['thumbnail'] && !film['Images']
      film.save
    end
  end
end
