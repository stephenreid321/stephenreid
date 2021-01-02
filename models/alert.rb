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
    # Telegram::Bot::Client.run(ENV['TELEGRAM_TOKEN']) do |bot|
    #   bot.api.send_message(chat_id: ENV['TELEGRAM_CHAT_ID'], text: text)
    # end
    # Strategy.bail if value.negative?
  end

  def self.admin_fields
    {
      ccowl_id: :text,
      text: :text,
      ticker: :text,
      value: :number,
      rule_id: :number
    }
  end
end
