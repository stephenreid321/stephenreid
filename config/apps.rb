Padrino.configure_apps do
  set :session_secret, ENV['SESSION_SECRET']
end

Padrino.mount('ActivateApp::App', :app_file => Padrino.root('app/app.rb')).to('/')