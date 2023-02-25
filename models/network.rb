class Network
  include Mongoid::Document
  include Mongoid::Timestamps

  field :slug, type: String
  field :name, type: String
  field :prompt, type: String
  field :filter_words, type: String

  has_many :videos, dependent: :destroy
  has_many :vterms, dependent: :destroy
  has_many :vedges, dependent: :destroy

  def self.admin_fields
    {
      slug: :text,
      name: :text,
      filter_words: :text,
      prompt: :text_area,
      videos: :collection,
      vterms: :collection,
      vedges: :collection
    }
  end

  # n = Network.last
  # y = y.split("\n").map { |id| id.strip }
  # y.each { |id| puts id; v = n.videos.create(youtube_id: id); if !v.errors.empty?; puts v.errors.full_messages; end }
  # n.create_edges  

  def filter_words_a
    filter_words ? filter_words.split(',').map(&:strip) : []
  end

  def interesting
    vterms.pluck(:term).sort_by { |t| -t.length }
  end

  def plurals
    interesting.map(&:pluralize)
  end

  def superterms
    superterms = []
    vterms.each do |x|
      vterms.each do |y|
        superterms << x if x.term != y.term && x.term.include?(y.term)
      end
    end
    superterms.pluck(:term)
  end

  def edgeless
    vterms.where(:id.nin => vedges.pluck(:source_id) + vedges.pluck(:sink_id))
  end

  def create_edges
    edgeless.each do |source|
      source.find_or_create_vedges
      source.set_see_also!
    end
    # vterms.set(see_also: nil)
    # vterms.each { |vterm| vterm.set_see_also! }
  end

  def find_or_create_vedge(source, sink)
    if !(vedge = vedges.find_by(source: source, sink: sink)) && !(vedge = vedges.find_by(source: sink, sink: source))
      puts "creating edge for #{source.term} - #{sink.term}"
      vedge = vedges.create(source: source, sink: sink)
    end
    vedge
  end
end
