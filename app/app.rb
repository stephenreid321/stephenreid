module ActivateApp
  class App < Padrino::Application
    register Padrino::Rendering
    register Padrino::Helpers
    register WillPaginate::Sinatra
    helpers Activate::DatetimeHelpers
    helpers Activate::ParamHelpers
    helpers Activate::NavigationHelpers
    
    register Padrino::Cache
    enable :caching
      
    require 'sass/plugin/rack'
    Sass::Plugin.options[:template_location] = Padrino.root('app', 'assets', 'stylesheets')
    Sass::Plugin.options[:css_location] = Padrino.root('app', 'assets', 'stylesheets')
    use Sass::Plugin::Rack

    use Airbrake::Rack::Middleware

    set :sessions, :expire_after => 1.year
    set :public_folder, Padrino.root('app', 'assets')
    set :default_builder, 'ActivateFormBuilder'

    Mail.defaults do
      delivery_method :smtp, {
        :user_name => ENV['SMTP_USERNAME'],
        :password => ENV['SMTP_PASSWORD'],
        :address => ENV['SMTP_ADDRESS'],
        :port => 587
      }
    end

    before do
      redirect "http://#{ENV['DOMAIN']}#{request.path}" if ENV['DOMAIN'] and request.env['HTTP_HOST'] != ENV['DOMAIN']
      fix_params!
      @og_desc = 'Social entrepreneur, activist and public speaker'
      @og_image = "http://#{ENV['DOMAIN']}/images/grand-opening-wide.jpg"
      @eth = '0x72e1638bd8cd371bfb04cf665b749a0e4ae38324'
    end

    error do
      Airbrake.notify(env['sinatra.error'], :session => session)
      erb :error, :layout => :application
    end

    not_found do
      erb :not_found, :layout => :application
    end

    get '/', :cache => true do
      erb :home
    end

    get '/podcast', :cache => true do
      @title = 'Podcast'
      erb :podcast
    end

    get '/calendar', :cache => true do
      @title = 'Calendar'
      erb :calendar
    end
     
    get '/habits', :cache => true do
      @title = 'Habits'
      erb :habits
    end

    get '/tarot', :cache => true do
      @title = 'Tarot'
      @og_image = "http://#{ENV['DOMAIN']}/images/tarotcards.jpg"
      erb :tarot
    end
    
    get '/books', :cache => true do
      @title = 'Books'
      erb :books
    end

    get '/darknet', :cache => true do
      @title = 'Step-by-step guide to the darknet'
      @og_desc = 'A step-by-step guide to using a darknet marketplace. Start to finish, it takes a couple of hours.'
      @og_image = "http://#{ENV['DOMAIN']}/images/marketplace/tor.png"
      erb :darknet
    end

    get '/why-use-the-darknet', :cache => true do
      @title = 'Why use the darknet to obtain psychedelics?'
      @og_desc = 'Why using the darknet to obtain psychedelics is better for you and better for society'
      erb :why_use_the_darknet
    end
    
    
    
    get '/places-plans' do
      @title = 'Places & Plans'
      if params[:map]
        @organisations = params[:plans] ? Organisation.all(filter: "AND({Interest} = 'upcoming', {Latitude} != '', {Longitude} != '')") : Organisation.all(filter: "AND({Latitude} != '', {Longitude} != '')")
        @view = 'map'                
        erb :map
      else
        erb :organisations
      end
    end      
    
    get '/clear-cache' do
      ActivateApp::App.cache.clear
      redirect '/'
    end
    
    get '/link' do
      redirect Fragment.all(filter: "{Name} = 'link'").first['Body']
    end

    get '/bio' do
      redirect '/'
    end

    get '/podcasts' do
      redirect '/podcast'
    end
            
    get '/ps' do
      redirect 'https://www.google.com/maps/place/The+Psychedelic+Society/@51.547382,-0.0449452,17z/data=!4m12!1m6!3m5!1s0x48761dff684f311b:0xa492a62a16335e19!2sThe+Psychedelic+Society!8m2!3d51.547382!4d-0.0427565!3m4!1s0x48761dff684f311b:0xa492a62a16335e19!8m2!3d51.547382!4d-0.0427565'
    end    

  end
end
