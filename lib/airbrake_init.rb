Airbrake.configure do |config|
  config.host = (ENV['AIRBRAKE_HOST'] || 'airbrake.io')
  config.project_id = (ENV['AIRBRAKE_PROJECT_ID'] || 1)
  config.project_key = (ENV['AIRBRAKE_PROJECT_KEY'] || ENV['AIRBRAKE_API_KEY'] || 'project_key')
  config.environment = Padrino.env
  if ENV['AIRBRAKE_HOST']
    config.job_stats = false
    config.query_stats = false
    config.performance_stats = false
    config.remote_config = false
  end
end

Airbrake.add_filter do |notice|
  should_ignore = notice[:errors].any? do |error|
    [
      %w[Sinatra::NotFound SignalException].include?(error[:type]),
      error[:type] == 'ArgumentError' && error[:message] && error[:message].include?('invalid %-encoding'),
      error[:type] == 'ThreadError' && error[:message] && error[:message].include?("can't be called from trap context"),
      error[:type] == 'Mongoid::Errors::Validations' && error[:message] && error[:message].include?('Ticket type is full')
    ].any?
  end

  notice.ignore! if should_ignore
end
