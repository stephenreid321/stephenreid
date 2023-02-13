workers Integer(ENV['WEB_CONCURRENCY'] || 0)
threads Integer(ENV['MIN_THREADS'] || 3), Integer(ENV['MAX_THREADS'] || 3)

preload_app!

port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'
