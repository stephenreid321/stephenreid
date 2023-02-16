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

  # n.vterms.each { |v| v.set_weight; v.save }
  # n.vterms.each { |x| n.vterms.each { |y| if x.term != y.term && x.term.include?(y.term); puts "#{x.term} includes #{y.term}"; end } }

  def filter_words_a
    filter_words ? filter_words.split(',').map(&:strip) : []
  end

  def interesting
    vterms.pluck(:term)
  end

  def plurals
    interesting.map { |term| term.pluralize }
  end

  def edgeless
    vterms.where(:id.nin => vedges.pluck(:source_id) + vedges.pluck(:sink_id))
  end

  def create_edges
    edgeless.each { |source|      
      source.find_or_create_vedges
    }
    vterms.set(see_also: nil)
    vterms.each { |vterm| vterm.set_see_also! }
  end

  def find_or_create_vedge(source, sink)
    if !(vedge = vedges.find_by(source: source, sink: sink)) && !(vedge = vedges.find_by(source: sink, sink: source))
      puts "creating edge for #{source.term} - #{sink.term}"
      vedge = vedges.create(source: source, sink: sink)
    end
    vedge
  end
end