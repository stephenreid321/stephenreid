class Asset
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ticker, type: String
  field :name, type: String
  field :color, type: String
  field :multiplier, type: Float
  field :status, type: String

  validates_presence_of :ticker

  has_many :holdings, dependent: :destroy

  def virtual_color
    Digest::MD5.hexdigest(ticker)[0..5].paint.opacity(0.5).to_rgb
  end

  def self.statuses
    ['', 'verified', 'excluded']
  end
end
