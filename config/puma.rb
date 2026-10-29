# Compile hot Ruby methods to machine code (Ruby builds without YJIT don't define enable)
RubyVM::YJIT.enable if defined?(RubyVM::YJIT.enable)

workers Integer(ENV['WEB_CONCURRENCY'] || 0)
threads Integer(ENV['MIN_THREADS'] || 3), Integer(ENV['MAX_THREADS'] || 3)
port ENV['PORT'] || 3001
environment ENV['RACK_ENV'] || 'development'

preload_app!
