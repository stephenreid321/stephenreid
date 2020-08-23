class Holding
  include Mongoid::Document
  include Mongoid::Timestamps

  field :weight, type: Float

  belongs_to :asset
  belongs_to :strategy

  def percent
    "#{(weight * 100).round(2)}%"
  end

  def summary
    "#{strategy.ticker} #{asset.ticker} #{percent}"
  end

  def self.admin_fields
    {
      summary: { type: :text, edit: false },
      strategy_id: :lookup,
      asset_id: :lookup,
      weight: :number
    }
  end
end
