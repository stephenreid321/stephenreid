IGNORED_ERRORS = {
  # Simple class name matches
  'Sinatra::NotFound' => nil,
  'SignalException' => nil,

  # Error types with specific message patterns
  'Sinatra::BadRequest' => [
    'invalid %-encoding',
    'Invalid multipart/form-data: EOFError',
    'invalid byte sequence in UTF-8'
  ],
  'ThreadError' => [
    "can't be called from trap context"
  ],
  'Errno::EIO' => [
    'Input/output error'
  ],
  'Encoding::CompatibilityError' => [
    'invalid byte sequence in UTF-8'
  ],
  'ArgumentError' => [
    'invalid byte sequence in UTF-8'
  ],
  'Airrecord::Error' => [
    'HTTP 503: Communication error',
    'HTTP 422: INVALID_FILTER_BY_FORMULA'
  ],
  'Errno::ECONNRESET' => [
    'Connection reset by peer'
  ]
}.freeze

Honeybadger.configure do |config|
  config.before_notify do |notice|
    error_type = notice.exception.class.name
    error_message = notice.error_message

    # Check if this error should be ignored
    should_ignore = IGNORED_ERRORS.any? do |ignored_type, message_patterns|
      next false unless error_type == ignored_type

      # If no message patterns specified, ignore all errors of this type
      return true if message_patterns.nil?

      # Check if any message pattern matches
      message_patterns.any? { |pattern| error_message&.include?(pattern) }
    end

    notice.halt! if should_ignore
  end
end
