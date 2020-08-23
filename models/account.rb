class Account
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :email, type: String
  field :admin, type: Boolean
  field :time_zone, type: String
  field :crypted_password, type: String

  def self.protected_attributes
    %w[admin]
  end

  attr_accessor :password

  validates_presence_of :name, :time_zone
  validates_presence_of     :email
  validates_length_of       :email,    within: 3..100
  validates_uniqueness_of   :email,    case_sensitive: false
  validates_format_of       :email,    with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\Z/i
  validates_presence_of     :password, if: :password_required
  validates_length_of       :password, within: 4..40, if: :password_required

  def self.admin_fields
    {
      name: :text,
      email: :text,
      admin: :check_box,
      time_zone: :select,
      password: { type: :password, new_hint: 'Leave blank to keep existing password' }
    }
  end

  def self.edit_hints
    {
      password: 'Leave blank to keep existing password'
    }
  end

  def firstname
    name.split(' ').first
  end

  def self.time_zones
    [''] + ActiveSupport::TimeZone::MAPPING.keys.sort
  end

  def uid
    id
  end

  def info
    { email: email, name: name }
  end

  def self.authenticate(email, password)
    account = find_by(email: /^#{::Regexp.escape(email)}$/i) if email.present?
    account && account.has_password?(password) ? account : nil
  end

  before_save :encrypt_password, if: :password_required

  def has_password?(password)
    ::BCrypt::Password.new(crypted_password) == password
  end

  def self.generate_password(len)
    chars = ('a'..'z').to_a + ('0'..'9').to_a
    Array.new(len) { chars[rand(chars.size)] }.join
  end

  private

  def encrypt_password
    self.crypted_password = ::BCrypt::Password.create(password)
  end

  def password_required
    crypted_password.blank? || password.present?
  end
end
