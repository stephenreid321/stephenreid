# Errors not worth reporting, by class: nil to ignore every one, or the messages to ignore it for
IGNORED_ERRORS = {
  'Sinatra::NotFound' => nil,
  'SignalException' => nil,
  'Sinatra::BadRequest' => ['invalid %-encoding', 'Invalid multipart/form-data', 'invalid byte sequence in UTF-8'],
  'ThreadError' => ["can't be called from trap context"],
  'Errno::EIO' => ['Input/output error'],
  'Encoding::CompatibilityError' => ['invalid byte sequence in UTF-8'],
  'ArgumentError' => ['invalid byte sequence in UTF-8'],
  'Errno::ECONNRESET' => ['Connection reset by peer']
}.freeze

Honeybadger.configure do |config|
  config.before_notify do |notice|
    next unless IGNORED_ERRORS.key?(notice.error_class)

    messages = IGNORED_ERRORS[notice.error_class]
    notice.halt! if messages.nil? || messages.any? { |message| notice.error_message.to_s.include?(message) }
  end
end
