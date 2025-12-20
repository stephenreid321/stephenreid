class Software < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Softwares'

  def self.iframely
    agent = Mechanize.new
    Software.all(filter: "AND({Featured} = 1, {Description} = '')").each do |software|
      result = agent.get("https://iframe.ly/api/iframely?url=#{URI.encode_www_form_component(software['URL'])}&api_key=#{ENV['IFRAMELY_API_KEY']}")
      json = JSON.parse(result.body.force_encoding('UTF-8'))
      software['Description'] = json['meta']['description']
      software['Images'] = [{ url: json['links']['thumbnail'].first['href'] }] if json['links']['thumbnail'] && !software['Images']
      software.save
    end
  end
end
