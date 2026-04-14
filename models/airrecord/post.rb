require 'shellwords'

class Post < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Posts'

  has_many :terms, class: 'Term', column: 'Terms'

  belongs_to :organisation, class: 'Organisation', column: 'Organisation'

  def self.sync_with_readwise
    conn = Faraday.new(url: 'https://readwise.io/api/v3') do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get('list', {
                          location: 'archive',
                          updatedAfter: 7.days.ago.iso8601
                        }) do |req|
      req.headers['Authorization'] = "Token #{ENV['READWISE_ACCESS_TOKEN']}"
      req.headers['Content-Type'] = 'application/json'
    end

    data = JSON.parse(response.body)
    data['results'].first(50).sort_by { |r| -Time.parse(r['last_moved_at']).to_i }.each do |r|
      url = r['source_url']
      url = url.gsub('youtu.be/', 'youtube.com/watch?v=')
      next if Time.parse(r['last_moved_at']) < 7.days.ago

      if Post.all(filter: "{Link} = '#{url}'").first
        puts "found #{url}"
        next
      end

      puts url

      post = Post.create(
        'Title' => r['title'],
        'Link' => url,
        'Body' => r['summary'],
        'Iframely' => Faraday.get("https://iframe.ly/api/iframely?url=#{URI.encode_www_form_component(url)}&api_key=#{ENV['IFRAMELY_API_KEY']}").body,
        'Created at' => Time.now
      )

      unless post['Title']
        json = JSON.parse(post['Iframely'])
        post['Title'] = json['meta']['title']
        post['Body'] = json['meta']['description']
        post.save
      end

      post.tagify
      post.bluesky
    end
  end

  def self.sync_with_pocket
    conn = Faraday.new(url: 'https://getpocket.com/v3/get') do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    response = conn.post do |req|
      req.headers['Content-Type'] = 'application/json; charset=UTF8'
      req.headers['X-Accept'] = 'application/json'
      req.body = {
        consumer_key: ENV['POCKET_CONSUMER_KEY'],
        access_token: ENV['POCKET_ACCESS_TOKEN'],
        detailType: :complete,
        state: :archive,
        count: 50
      }.to_json
    end

    data = JSON.parse(response.body)
    data['list'].sort_by { |_, p| -p['time_updated'].to_i }.each do |_, p|
      url = p['resolved_url']
      url = url.gsub('youtu.be/', 'youtube.com/watch?v=')
      puts url
      break if Post.all(filter: "{Link} = '#{url}'").first

      post = Post.create(
        'Title' => p['resolved_title'],
        'Link' => url,
        'Body' => p['excerpt'],
        'Iframely' => Faraday.get("https://iframe.ly/api/iframely?url=#{URI.encode_www_form_component(url)}&api_key=#{ENV['IFRAMELY_API_KEY']}").body,
        'Created at' => Time.now
      )
      unless post['Title']
        json = JSON.parse(post['Iframely'])
        post['Title'] = json['meta']['title']
        post['Body'] = json['meta']['description']
        post.save
      end
      post.tagify
      post.bluesky
    end
  end

  def tagify(skip_linking: false)
    post = self
    json = JSON.parse(post['Iframely'])
    twitter = post['Title']
    facebook = post['Title']
    replacements = []
    additions = []

    Term.all(sort: { 'Priority' => 'desc' }).each do |term|
      i = term['Case sensitive'] ? false : true
      t = term['Name']
      replacements << term if post['Title'].match(i ? /\b#{t}\b/i : /\b#{t}\b/)
      additions << term if [post['Body']].any? { |x| x && x.match(i ? /\b#{t}\b/i : /\b#{t}\b/) }
      additions << term if json['meta'] && [json['meta']['title'], json['meta']['category'], json['meta']['author'], json['meta']['description'], json['meta']['keywords']].any? { |x| x && x.match(i ? /\b#{t}\b/i : /\b#{t}\b/) }
    end

    replacements.each do |term|
      i = term['Case sensitive'] ? false : true
      t = term['Name']
      hashtag = t.include?(' ') ? t.gsub(' ', '_').gsub('-', '_').camelize : t
      if term['Organisation']
        twitter = twitter.gsub(i ? /\b#{t}\b/i : /\b#{t}\b/, "@#{term.organisation['Twitter username']}")
        # facebook = facebook.gsub(i ? /#{t}/i : /#{t}/, "@[#{term.organisation['Facebook page username']}]")
      else
        twitter = twitter.gsub(i ? /\b#{t}\b/i : /\b#{t}\b/, "##{hashtag}")
        facebook = facebook.gsub(i ? /\b#{t}\b/i : /\b#{t}\b/, "##{hashtag}")
      end
    end

    twitter_add = []
    facebook_add = []
    (additions - replacements).each do |term|
      t = term['Name']
      hashtag = t.include?(' ') ? t.gsub(' ', '_').gsub('-', '_').camelize : t
      if term['Organisation']
        twitter_add << "@#{term.organisation['Twitter username']}"
        # facebook_add << "@[#{term.organisation['Facebook page username']}]"
      else
        twitter_add << "##{hashtag}"
        facebook_add << "##{hashtag}"
      end
    end

    if (organisation = Organisation.all(filter: "{Domain} = '#{URI(post['Link']).host.gsub('www.', '').split('.').last(2).join('.')}'").first)
      post.organisation = organisation
      unless organisation['No domain tag']
        twitter_add << "@#{organisation['Twitter username']}"
        # facebook_add << "@[#{organisation['Facebook page username']}]"
      end
    end

    (additions + replacements).map { |term| term['Emoji'] }.compact.each do |emoji|
      twitter_add << emoji
      facebook_add << emoji
    end

    twitter_add.uniq.each { |x| twitter = "#{twitter} #{x}" }
    facebook_add.uniq.each { |x| facebook = "#{facebook} #{x}" }

    post.terms = (additions + replacements).uniq
    post['Twitter text'] = twitter
    post['Facebook text'] = facebook
    post.save

    unless skip_linking
      checked = []
      post.terms.each do |source|
        post.terms.each do |sink|
          next unless source.id != sink.id && !checked.include?([source.id, sink.id]) && !checked.include?([sink.id, source.id])

          puts "#{source['Name']} <-> #{sink['Name']}"
          checked << [source.id, sink.id]

          term_link = TermLink.find_or_create(source, sink)

          unless (term_link['Posts'] || []).include?(post.id)
            term_link['Posts'] = ((term_link['Posts'] || []) + [post.id])
            term_link.save
          end
        end
      end
    end

    self['Twitter text']
  end

  def self.extract_iframely_metadata(iframely_json)
    json = iframely_json.is_a?(String) ? JSON.parse(iframely_json) : iframely_json
    {
      title: json['meta'] && json['meta']['title'] ? json['meta']['title'] : '',
      description: json['meta'] && json['meta']['description'] ? json['meta']['description'].truncate(150) : '',
      thumbnail: json['links'] && json['links']['thumbnail'] ? json['links']['thumbnail'].first['href'] : ''
    }
  end

  def self.post_to_bluesky(text, url: nil, title: nil, description: nil, thumbnail: nil)
    args = [Shellwords.escape(text)]
    args << Shellwords.escape(url) if url
    args << Shellwords.escape(title) if title
    args << Shellwords.escape(description) if description
    args << Shellwords.escape(thumbnail) if thumbnail
    `python #{Shellwords.escape(Padrino.root.to_s)}/tasks/bluesky.py #{args.join(' ')}`
  end

  def bluesky
    metadata = Post.extract_iframely_metadata(self['Iframely'])
    Post.post_to_bluesky(
      self['Title'],
      url: self['Link'],
      title: self['Title'],
      description: metadata[:description],
      thumbnail: metadata[:thumbnail]
    )
  end

  def refresh_iframely
    post = self
    agent = Mechanize.new
    result = agent.get("https://iframe.ly/api/iframely?url=#{URI.encode_www_form_component(post['Link'].split('#').first)}&api_key=#{ENV['IFRAMELY_API_KEY']}")
    post['Iframely'] = result.body.force_encoding('UTF-8')
    post.save
  end
end
