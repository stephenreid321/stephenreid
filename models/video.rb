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
      view_count: :number
    }
  end

  before_validation do
    set_title if title.blank?
    set_transcript if transcript.blank?
    set_text if text.blank?
    set_view_count if view_count.blank?
    errors.add(:title, 'is invalid') if !title.match(/game b/i) && !title.match(/daniel schmachtenberger/i)
  end

  validates_uniqueness_of :youtube_id

  def set_title
    r = Faraday.get("https://www.youtube.com/watch?v=#{youtube_id}")
    self.title = r.body.match(%r{<title>(.+)</title>})[1].force_encoding('UTF-8')
  end

  def set_transcript
    r = Faraday.get("https://youtubetranscript.com/?server_vid=#{youtube_id}")
    # deal with "\xE2" from ASCII-8BIT to UTF-8 (Encoding::UndefinedConversionError)
    self.transcript = r.body.force_encoding('UTF-8')
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
    lines_including_term = lines.select { |l| l.include?(term) || l.include?(term.pluralize) }
    lines_including_term.map do |l|
      prev = lines[(lines.index(l) - 1)]
      [
        prev && (m = prev.match(/start="([\d.]+)"/)) ? m[1] : l[1],
        [lines[(lines.index(l) - 1)], l, lines[(lines.index(l) + 1)]].map { |l| l.split('>').last }.join(' ')
        .gsub(/\b#{term.pluralize}\b/, %(<mark>#{term}</mark>))
        .gsub(/\b#{term}\b/, %(<mark>#{term}</mark>))
      ]
    end
  end

  def self.populate
    Video.delete_all
    youtube_ids = %w[E_cyCuCKQhs eq_gaazINkA 7LqaotiGWjQ hGRNUw559SE _b4qKv1Ctv8 YPJug0s2u4w hUE0Q7lv94k db-Xn2gzGxU tJQac_T_rPo MYCvaVqZebA 0v5RiMdSqwk nQRzxEobWco 9QGrffjOFko GWk-ZpJdRFg 8Es_WTEgZHE _7aIgHoydP8 p4NlLuNj0v8 Z_wPQCU5O6w eh7qvXfGQho Kt4f_gcEnh4 G70qtM66iY8 8XCXvzQdcug 3bxzo79SjpE XQpoGL0yIFE aX5n0DYXnUQ LLgv2QJRYSg fWshjsIrUSI mQstRd7opv4 aNj8UiPgqqQ ya_p4RIorXw ndehWd9N9Z4 ZNcyc_sEtpU _eoB4g3gCmw wO1WVguNQAM _BofVO-4yNc MBcoTHlD8r8 Nkv5mpBA8o4 hKvVdGNzCQk UoHmEYZLqmk R2sIG6l4uU0 zi5-90TnI3Y lls_2tfWcUI ZCOfUYrZJMQ V2wuvrgYyh8 01rVKtbqtnA 0snD5FZCVII rrozCypcUx4 MRV-ESY6Obs qd5vPs9cRYI 8xDgk0uGw_s _Oflv3u0HEA VPAOzlqcGIQ SioR1jgdhnk kTFqnPEyweE Pyy3veuvXVE tQkQrc3Ant4 aZhiwxxn3K8 weZqeVh2Exs Wk2HinTpRwQ E0_j2-pLunY q8mleq4VNm8 2YgNYdL7HTk dGW5J3EbOUY m3VGg2kQWR4 Fl8pGMjM9kM LtbMps1PDFc jUn7_85R0M4 X_7U1ApSzaM VLGjzGbPxVI zpGrU99fAA8 WVEP0zAK-xQ U0YJ0C81n4s IfoPitvLY7c 2fAy18JawYI H0ocPsqBKS4 PKz9TAsqsRo Kep8Fi_rUUI 611ctV-HStQ tNO_3JFLVUc I9I7p1eho3k dtxNgnBw8Ao U1QJtDCCMLA pSQqaclDmZ4 SkItTnRJ_1M 2SopiHEqfRQ uhVArr7R-aU ammJN0yCCbs 4pf38y5rFrE zQ0l56vjTss kbg8nHuNggU A41z7UD3NsU Kr2nhiNCOXo Fj6UjIV2VQQ 2p-GlhLQdY0 MZMSs2SLmSw WRohQKNNuM4 EfNgW-On6hw i6-cc71ALQc QAd9O6a6R5w 9LquQ4GgY5Y ZIV1Uw2VyF8 YcIlDc96Azs tWfyOU07vgE PnrL_9V0QMs tj9RceVQBxc mPHUN18BbNo ztfz5EdYxL0 CElwzOUbsGg ZXHagfNHKws HjChfAJy0g8 1rj9NtQafb8 LmlbhD6LbSA SxS1rIXXaQ4 fowcm7b8Dlw qwILqzrvncQ BWfwZvfaoYA yTSWDnhK-M4 vPSXsOeX6lM 6fWfvO72vAw Cqq840poanw GPumhxH3JHA hV9PJhhqw5w zWpKVTyx8R0 vLwlsQYBQ1w fcgOxHHp_i8 EsvG3zbKGa4 kLJ2QztR3ug Z7-Od0e0gq0 QZ9iRByzUJs 22TrTXZLmmU OLWihHrj6zs qKFY5OflSrc xnfOuiddmFY NABTu6VOroc ig-bWt2y1VE IVyq4WpmvRM Xhrr-fJCTWY j6nJmVcx6v8 BIKDNStlnL4 SWEoLn54d4U qxtkUJPg7os K2_1tnGL5eQ JBU06Wswc7c 2HfbPJXHmQM E8cSGX02bqA DcNG-gGxroY toZPGhq3VqQ a6ejROOyHW0 5Rxhyvyq7ew J9f5tuzzFxY mm9AE-oHlPk kmHyhJdSW5o z2rYFnDx6nQ IqLELspOa7g xreo0fw-4_A nOnyWZMvkg4 jzYOybiP7Dg 2zD0kQB6d0M uEAsKkjDURs 3lil4invvSI jQAhGT0nKkI 9TQHtaRXntQ vPbOyjtv5PU LetPkDGIyy0 ggf4ouFJ2x0 eTeLyBxjX9k T9v0IAFPrm0 U6Fo8Ee0x8Q -WQ7QbJGWRE 1r2TSpSNjDI ib4v9cG_ZA8 0dYoSctj3C8 9psdN65IzOw FschjBcFElk vfKR0Nyp--Q AdlYvrKa16c z7DZCChfmf8 17KFrJj1sMQ iF8R1hJT-24]
    youtube_ids.each { |youtube_id| Video.create(youtube_id: youtube_id) }
    # posts = []
    # ['daniel schmachtenberger'].each do |q|
    #   posts = Post.all(filter: "
    #     OR(
    #       FIND(LOWER('#{q}'), LOWER({Title})) > 0,
    #       FIND(LOWER('#{q}'), LOWER({Body})) > 0,
    #       FIND(LOWER('#{q}'), LOWER({Iframely})) > 0
    #     )
    #   ")
    # end
    # posts.each do |post|
    #   puts post['Title']
    #   next unless %w[youtube youtu.be].any? { |domain| post['Link'].include?(domain) }

    #   # https://www.youtube.com/watch?v=QX4DZBd0o5A
    #   # https://youtu.be/QX4DZBd0o5A
    #   youtube_id = post['Link'].split('v=').last.split('&').first.split('/').last
    #   next unless Video.where(youtube_id: youtube_id).count == 0

    #   puts youtube_id
    #   video = Video.new(youtube_id: youtube_id)
    #   video.save
    # end
    # nil
  end
end
