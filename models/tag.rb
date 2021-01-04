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

  %w[1h 24h 7d].each do |p|
    define_method :"price_change_percentage_#{p}_in_currency" do
      a = coins.map(&:"price_change_percentage_#{p}_in_currency").compact
      if (n = a.count) > 0
        a.sum / n
      end
    end
  end

  def market_cap_change_percentage_24h
    a = coins.map(&:market_cap_change_percentage_24h).compact
    if (n = a.count) > 0
      a.sum / n
    end
  end

  def background_color
    tags = Tag.order('holding desc').where(:holding.gt => 0)
    i = tags.pluck(:id).index(id)
    i = (tags.count - 1) - i if i.odd?
    i && !tags.empty? ? '#2DB963'.paint.spin(0 - (i.to_f / (tags.count - 1)) * (360 - (360 / tags.count))).lighten(20) : '#666666'
  rescue StandardError
    '#666666'
  end
end
