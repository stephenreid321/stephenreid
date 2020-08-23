class Asset
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ticker, type: String
  field :name, type: String

  validates_presence_of :ticker

  has_many :holdings, dependent: :destroy

  def self.admin_fields
    {
      ticker: :text,
      name: :text,
      holdings: :collection
    }
  end
end
