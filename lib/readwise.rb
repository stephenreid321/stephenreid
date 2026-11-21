# Readwise Reader's API, as the account whose token is READWISE_ACCESS_TOKEN
module Readwise
  # The documents archived since a time, oldest first, with source_url, title, author, summary, image_url and
  # last_moved_at. YouTube's short links are made long, so a link is the same wherever it's posted
  def self.archived_since(time, token: ENV.fetch('READWISE_ACCESS_TOKEN'))
    response = Faraday.get('https://readwise.io/api/v3/list', { location: 'archive', updatedAfter: time.iso8601 },
                           { 'Authorization' => "Token #{token}" })
    raise "Readwise: #{response.status}" unless response.success?

    JSON.parse(response.body)['results']
        .select { |r| Time.parse(r['last_moved_at']) >= time }
        .sort_by { |r| Time.parse(r['last_moved_at']) }
        .each { |r| r['source_url'] = r['source_url'].gsub('youtu.be/', 'youtube.com/watch?v=') }
  end
end
