class Vtermship
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :network, index: true
  belongs_to :vterm, index: true
  belongs_to :video, index: true

  field :weight, type: Integer

  validates_uniqueness_of :vterm, scope: :video

  def self.admin_fields
    {
      network_id: :lookup,
      vterm_id: :lookup,
      video_id: :lookup,
      weight: :number
    }
  end

  before_validation do
    set_weight if weight.blank?
  end

  def set_weight
    self.weight = video.term(vterm.term).count
  end
end
