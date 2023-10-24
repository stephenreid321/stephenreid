class Post < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Posts'

  has_many :terms, class: 'Term', column: 'Terms'

  belongs_to :organisation, class: 'Organisation', column: 'Organisation'

  def cast
    post = self
    `python #{Padrino.root}/tasks/cast.py "#{post['Twitter text'].gsub('"', '\"')}" "#{post['Link'].gsub('"', '\"')}"`
  end

  def tagify(skip_linking: false)
    post = self
    json = JSON.parse(post['Iframely'])
    twitter = post['Title']
    facebook = post['Title']
    replacements = []
    additions = []

    post['Link'] = post['Link'].gsub('youtu.be/', 'youtube.com/watch?v=')

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

    if (organisation = Organisation.all(filter: "{Domain} = '#{URI(post['Link']).host.gsub('www.', '')}'").first)
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
end
