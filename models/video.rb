class Video
  include Mongoid::Document
  include Mongoid::Timestamps

  field :youtube_id, type: String
  field :title, type: String
  field :transcript, type: String

  def self.admin_fields
    {
      youtube_id: { type: :text, full: true },
      title: :text_area,
      transcript: :text_area
    }
  end

  before_validation do
    set_title if title.blank?
    set_transcript if transcript.blank?
  end

  def set_title
    r = Faraday.get("https://www.youtube.com/watch?v=#{youtube_id}")
    self.title = r.body.match(%r{<title>(.+)</title>})[1].force_encoding('UTF-8')
  end

  def set_transcript
    r = Faraday.get("https://youtubetranscript.com/?server_vid=#{youtube_id}")
    # deal with "\xE2" from ASCII-8BIT to UTF-8 (Encoding::UndefinedConversionError)
    self.transcript = r.body.force_encoding('UTF-8')
  end

  def text
    Nokogiri::XML(transcript.gsub('</text><text', '</text> <text')).text
  end

  def term(term)
    lines = transcript.split('</text>')
    lines_including_term = lines.select { |l| l.include?(term) }
    lines_including_term.map do |l|
      [
        lines[(lines.index(l) - 1)].match(/start="([\d.]+)"/)[1],
        [lines[(lines.index(l) - 1)], l, lines[(lines.index(l) + 1)]].map { |l| l.split('>').last }.join(' ').gsub(term, "<strong>#{term}</strong>")
      ]
    end
  end

  def self.populate
    posts = []
    ['daniel schmachtenberger'].each do |q|
      posts = Post.all(filter: "
        OR(
          FIND(LOWER('#{q}'), LOWER({Title})) > 0,
          FIND(LOWER('#{q}'), LOWER({Body})) > 0,
          FIND(LOWER('#{q}'), LOWER({Iframely})) > 0
        )
      ")
    end
    posts.each do |post|
      puts post['Title']
      next unless %w[youtube youtu.be].any? { |domain| post['Link'].include?(domain) }

      # https://www.youtube.com/watch?v=QX4DZBd0o5A
      # https://youtu.be/QX4DZBd0o5A
      youtube_id = post['Link'].split('v=').last.split('&').first.split('/').last
      next unless Video.where(youtube_id: youtube_id).count == 0

      puts youtube_id
      video = Video.new(youtube_id: youtube_id)
      video.save
    end
    nil
  end
end
