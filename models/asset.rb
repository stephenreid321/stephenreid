class Asset
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ticker, type: String
  field :name, type: String
  field :color, type: String
  field :multiplier, type: Float
  field :verified, type: Boolean
  field :excluded, type: Boolean

  validates_presence_of :ticker

  has_many :holdings, dependent: :destroy

  def self.admin_fields
    {
      ticker: :text,
      name: :text,
      color: :text,
      multiplier: :number,
      verified: :check_box,
      excluded: :check_box,
      holdings: :collection
    }
  end

  def self.unverified
    where(:verified.ne => true)
  end
end
