class Tag
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :priority, type: Integer
  field :holding, type: Float

  has_many :coins, dependent: :nullify

  def self.admin_fields
    {
      name: :text,
      priority: :number,
      holding: :number
    }
  end

  def self.update_holdings
    Tag.all.each(&:update_holding)
  end

  def update_holding
    update_attribute(:holding, coins.sum { |coin| coin.holding })
  end

  def self.holding
    Tag.sum { |tag| tag.holding }
  end

  def background_color
    tags = Tag.order('holding desc').where(:holding.gt => 0)
    i = tags.pluck(:id).index(id)
    i ? '#B92D2D'.paint.spin(-i * 180 / tags.count) : '#6C757D'
  end
end
