class Tag
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :background_color, type: String
  field :color, type: String

  def self.admin_fields
    {
      name: :text,
      background_color: :text,
      color: :text
    }
  end
end
