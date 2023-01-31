class Vedge
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :source, class_name: 'Vterm', inverse_of: :vedges_as_source, index: true
  belongs_to :sink, class_name: 'Vterm', inverse_of: :vedges_as_sink, index: true
  belongs_to :network

  field :weight, type: Integer

  def self.admin_fields
    {
      source_id: :lookup,
      sink_id: :lookup,
      weight: :number,
      network_id: :lookup
    }
  end

  validates_uniqueness_of :source, scope: :sink

  def videos
    ids = []
    ids += network.videos.and({ text: /\b#{source.term}\b/i }, { text: /\b#{sink.term}\b/i }).pluck(:id)
    ids += network.videos.and({ text: /\b#{source.term.pluralize}\b/i }, { text: /\b#{sink.term}\b/i }).pluck(:id) if source.term != source.term.pluralize
    ids += network.videos.and({ text: /\b#{source.term}\b/i }, { text: /\b#{sink.term.pluralize}\b/i }).pluck(:id) if sink.term != sink.term.pluralize
    ids += network.videos.and({ text: /\b#{source.term.pluralize}\b/i }, { text: /\b#{sink.term.pluralize}\b/i }).pluck(:id) if source.term != source.term.pluralize && sink.term != sink.term.pluralize
    network.videos.where(:id.in => ids)
  end

  before_validation do
    set_weight if weight.blank?
  end

  def set_weight
    self.weight = videos.count
  end

end
