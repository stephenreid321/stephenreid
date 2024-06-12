class Post < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Posts'

  has_many :terms, class: 'Term', column: 'Terms'

  belongs_to :organisation, class: 'Organisation', column: 'Organisation'

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
    data['list'].each_value do |p|
      url = p['resolved_url']
      url = url.gsub('youtu.be/', 'youtube.com/watch?v=')
      puts url
      break if Post.all(filter: "{Link} = '#{url}'").first

      post = Post.create(
        'Title' => p['resolved_title'],
        'Link' => url,
        'Body' => p['excerpt'],
        'Iframely' => Faraday.get("https://iframe.ly/api/iframely?url=#{url}&api_key=#{ENV['IFRAMELY_API_KEY']}").body,
        'Created at' => Time.now
      )
      unless post['Title']
        json = JSON.parse(post['Iframely'])
        post['Title'] = json['meta']['title']
        post['Body'] = json['meta']['description']
        post.save
      end
      post.tagify
      post.cast
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

  def cast
    post = self
    `python #{Padrino.root}/tasks/cast.py "#{post['Title'].gsub('"', '\"')}" "#{post['Link'].gsub('"', '\"')}"`
  end

  def countdown(n)
    n.downto(1) do |i|
      puts i
      sleep 1
    end
  end

  def wizper!
    post = self

    puts 'downloading'
    audio_path = `python tasks/youtube_audio.py "#{post['Link']}"`.strip

    puts 'uploading'
    new_audio_path = "#{post['Title'].parameterize}.mp4"
    File.rename(audio_path, new_audio_path)
    audio_upload = Upload.create(file: File.open(new_audio_path))

    puts 'getting transcript'
    r = `python tasks/wizper.py "#{audio_upload.file.url}"`
    audio_upload.destroy

    puts 'saving txt'
    txt = JSON.parse(r)['text']
    txt_path = "#{post['Title'].parameterize}.txt"
    File.write(txt_path, txt)
    txt_upload = Upload.create(file: File.open(txt_path))
    post['Wizper txt'] = [{ url: txt_upload.file.url }]

    post.save
    txt_upload.destroy
    txt
  end

  def essay!
    post = self
    prompt = "Write a markdown-formatted essay based on this podcast transcript, as if by a listener of the podcast, with a ## header for each topic covered. Don't mention that you're a listener.\n\n#{URI.open(post['Wizper txt'][0]['url']).read}"

    post['Generated by AI'] = 'Gemini 1.5 Pro'
    response = GEMINI_PRO.generate_content(
      {
        contents: { role: 'user', parts: { text: prompt } },
        generationConfig: { maxOutputTokens: 8192 }
      }
    )
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')

    # post['Generated by AI'] = 'Claude 3 Opus'
    # client = Anthropic::Client.new
    # response = client.messages(
    #   parameters: {
    #     # model: 'claude-3-haiku-20240307',
    #     model: 'claude-3-opus-20240229',
    #     messages: [
    #       { role: 'user', content: prompt }
    #     ],
    #     max_tokens: 4096
    #   }
    # )
    # content = response['content'].first['text']

    puts "#{content}\n\n"
    post['Essay'] = content

    post.save
  end

  def note
    post = self
    browser = Ferrum::Browser.new
    browser.go_to('https://substack.com/sign-in')
    browser.at_css('a.login-option').click
    browser.at_css("input[name='email']").focus.type(ENV['SUBSTACK_EMAIL'])
    browser.at_css("input[name='password']").focus.type(ENV['SUBSTACK_PASSWORD'])
    browser.at_css('button[type="submit"]').click
    countdown 5
    browser.screenshot(path: '1.png')
    browser.at_css('div[class*=sideNav] button.pencraft').click
    browser.at_css('div.tiptap').focus.type(post['Title'], :Enter, :Enter, post['Link'], :Enter)
    countdown 5
    browser.at_css('div[class*=composerModal] button[class*=priority_primary]').click
    countdown 5
    browser.screenshot(path: '2.png')
  end
end
