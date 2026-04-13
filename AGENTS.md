This is a Ruby/Mongo app based on the Padrino framework, which is in turn based on Sinatra. (It is NOT a Rails app.)

The ORM is Mongoid, not ActiveRecord.

## Files in lib

Files in lib are auto-loaded by Padrino.load!. No explicit require is necessary.

## Mongo

We set `Mongoid.raise_not_found_error = false` in `boot.rb` so Model.find(id) returns nil for invalid ids.

Please note that Mongo indexes are created directly in the database, and are not defined in model files.

## Dependencies

Ruby gems: 

@Gemfile

Frontend dependencies:

@app/views/layouts/_dependencies.erb
