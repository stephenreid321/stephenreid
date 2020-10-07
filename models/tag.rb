class Tag
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :background_color, type: String
  field :color, type: String
  field :priority, type: Integer

  has_many :coins, dependent: :nullify

  def self.admin_fields
    {
      name: :text,
      background_color: :text,
      color: :text,
      priority: :number
    }
  end

  def holding
    coins.sum { |coin| coin.holding }
  end

  def self.holding
    Tag.all.sum { |tag| tag.holding }
  end

  def relative_holding
    holding / Tag.holding
  end
end
