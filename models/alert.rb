class Alert
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ccowl_id, type: String
  field :text, type: String
  field :ticker, type: String
  field :value, type: Float
  field :rule_id, type: Integer

  validates_presence_of :ccowl_id
  validates_uniqueness_of :ccowl_id

  after_create do
    Strategy.bail(text: text)
  end

  def self.admin_fields
    {
      ccowl_id: :text,
      text: :text,
      ticker: :text,
      value: :number,
      rule_id: :integer
    }
  end
end
