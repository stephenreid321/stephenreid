class Vedge
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :source, class_name: 'Vterm', inverse_of: :vedges_as_source, index: true
  belongs_to :sink, class_name: 'Vterm', inverse_of: :vedges_as_sink, index: true

  field :weight, type: Integer

  def self.admin_fields
    {
      source_id: :lookup,
      sink_id: :lookup,
      weight: :number
    }
  end

  validates_uniqueness_of :source, scope: :sink

  def videos
    ids = []
    ids += Video.and({ text: /\b#{source.term}\b/i }, { text: /\b#{sink.term}\b/i }).pluck(:id)
    ids += Video.and({ text: /\b#{source.term.pluralize}\b/i }, { text: /\b#{sink.term}\b/i }).pluck(:id) if source.term != source.term.pluralize
    ids += Video.and({ text: /\b#{source.term}\b/i }, { text: /\b#{sink.term.pluralize}\b/i }).pluck(:id) if sink.term != sink.term.pluralize
    ids += Video.and({ text: /\b#{source.term.pluralize}\b/i }, { text: /\b#{sink.term.pluralize}\b/i }).pluck(:id) if source.term != source.term.pluralize && sink.term != sink.term.pluralize
    Video.where(:id.in => ids)
  end

  before_validation do
    set_weight if weight.blank?
  end

  def set_weight
    self.weight = videos.count
  end

  def self.find_or_create(source, sink)
    if !(vedge = Vedge.find_by(source: source, sink: sink)) && !(vedge = Vedge.find_by(source: sink, sink: source))
      vedge = Vedge.create(source: source, sink: sink)
    end
    vedge
  end
end
