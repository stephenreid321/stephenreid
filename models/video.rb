class Video
  include Mongoid::Document
  include Mongoid::Timestamps

  field :youtube_id, type: String
  field :title, type: String
  field :transcript, type: String
  field :text, type: String
  field :view_count, type: Integer

  def self.admin_fields
    {
      youtube_id: :text,
      title: { type: :text, full: true },
      transcript: :text_area,
      text: :text_area,
      view_count: :number,
      network_id: :lookup
    }
  end

  belongs_to :network

  before_validation do
    set_title if title.blank?
    set_transcript if transcript.blank?
    set_text if text.blank?
    set_view_count if view_count.blank?
    errors.add(:title, 'is invalid') unless network.filter_words.empty? || network.filter_words.any? { |word| title.match(/#{word}/i) }
  end

  validates_uniqueness_of :youtube_id

  def set_title
    r = Faraday.get("https://www.youtube.com/watch?v=#{youtube_id}")
    self.title = r.body.match(%r{<title>(.+)</title>})[1].force_encoding('UTF-8')
  end

  def set_transcript
    r = Faraday.get("https://youtubetranscript.com/?server_vid=#{youtube_id}")
    self.transcript = r.body.force_encoding('UTF-8')
    tidy_transcript
  end

  def tidy_transcript
    Vterm.dashed_terms_to_undash.each do |term|
      self.transcript = transcript.gsub(/#{term}/i, term.gsub('-', ''))
    end
    Vterm.spaced_terms_to_unspace.each do |term|
      self.transcript = transcript.gsub(/#{term}/i, term.gsub(' ', ''))
    end
    Vterm.spaced_terms_to_dash.each do |term|
      self.transcript = transcript.gsub(/#{term}/i, term.gsub(' ', '-'))
    end
  end

  def set_text
    self.text = Nokogiri::XML(transcript.gsub('</text><text', '</text> <text')).text
  end

  def set_view_count
    self.view_count = JSON.parse(Faraday.get("https://returnyoutubedislikeapi.com/votes?videoId=#{youtube_id}").body)['viewCount']
    sleep 1
  end

  def term(term)
    lines = transcript.downcase.split('</text>')
    lines_including_term = lines.select { |l| l =~ /\b#{term}\b/i || l =~ /\b#{term.pluralize}\b/i }
    lines_including_term.map do |l|
      prev = lines[(lines.index(l) - 1)]
      [
        prev && (m = prev.match(/start="([\d.]+)"/)) ? m[1] : l[1],
        [lines[(lines.index(l) - 1)], l, lines[(lines.index(l) + 1)]].map { |l| l.split('>').last }.join(' ')
                                                                     .gsub(/\b(#{term.pluralize})\b/i, %(<mark>\\0</mark>))
                                                                     .gsub(/\b(#{term})\b/i, %(<mark>\\0</mark>))
      ]
    end
  end

  def terms(a, b)
    lines = transcript.downcase.split('</text>')
    lines_including_term = lines.select { |l| l =~ /\b#{a}\b/i || l =~ /\b#{a.pluralize}\b/i || l =~ /\b#{b}\b/i || l =~ /\b#{b.pluralize}\b/i }
    lines_including_term.map do |l|
      prev = lines[(lines.index(l) - 1)]
      [
        prev && (m = prev.match(/start="([\d.]+)"/)) ? m[1] : l[1],
        [lines[(lines.index(l) - 1)], l, lines[(lines.index(l) + 1)]].map { |l| l.split('>').last }.join(' ')
                                                                     .gsub(/\b(#{a.pluralize})\b/i, %(<mark>\\0</mark>))
                                                                     .gsub(/\b(#{a})\b/i, %(<mark>\\0</mark>))
                                                                     .gsub(/\b(#{b.pluralize})\b/i, %(<mark>\\0</mark>))
                                                                     .gsub(/\b(#{b})\b/i, %(<mark>\\0</mark>))
      ]
    end
  end
end
