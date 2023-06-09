class Upload
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model

  field :file_uid, type: String

  def self.admin_fields
    {
      file_uid: { type: :text, disabled: true },
      file: :file
    }
  end

  dragonfly_accessor :file

end