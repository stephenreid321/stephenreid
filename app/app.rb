module ActivateApp
  class App < Padrino::Application
    register Padrino::Rendering
    register Padrino::Helpers
    register WillPaginate::Sinatra
    helpers Activate::DatetimeHelpers
    helpers Activate::ParamHelpers
    helpers Activate::NavigationHelpers
        
    require 'sass/plugin/rack'
    Sass::Plugin.options[:template_location] = Padrino.root('app', 'assets', 'stylesheets')
    Sass::Plugin.options[:css_location] = Padrino.root('app', 'assets', 'stylesheets')
    use Sass::Plugin::Rack      
            
    use Dragonfly::Middleware       
    use Airbrake::Rack::Middleware
    use OmniAuth::Builder do
      provider :account
    end 
    OmniAuth.config.on_failure = Proc.new { |env|
      OmniAuth::FailureEndpoint.new(env).redirect_to_failure
    }
    
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
      Time.zone = current_account.time_zone if current_account and current_account.time_zone    
      fix_params!
      @_params = params; def params; @_params; end # force controllers to inherit the fixed params
      @title = 'Stephen Reid'
      @og_desc = 'Stephen Reid is the founder and co-director of the Psychedelic Society, the creator of Huddl and psychedelic.community, the press officer for the Breaking Convention Conference on Psychedelic Consciousness and is currently exploring the idea of a Metamonastery'
      @og_image = Preview.find_or_create_by(url: "http://#{ENV['DOMAIN']}#{request.path}").try(:image).try(:url)
      @eth = '0x72e1638bd8cd371bfb04cf665b749a0e4ae38324'
    end        
                
    error do
      Airbrake.notify(env['sinatra.error'], :session => session)
      erb :error, :layout => :application
    end        
    
    not_found do
      erb :not_found, :layout => :application
    end
    
    get :home, :map => '/' do
      @title = 'Stephen Reid'
      if params[:map]
        @places = Place.all
        @places = @places.where(category: 'upcoming') if params[:plans]
        erb :map 
      else 
        erb :places
      end            
    end
    
    get '/podcasts' do
      @title = 'Podcasts · Stephen Reid'
      erb :podcasts
    end    
    
    get '/calendar' do
      @title = 'Calendar · Stephen Reid'
      erb :calendar
    end
    
    get '/bio' do
      @title = 'Bio · Stephen Reid'
      erb :bio
    end
           
    get '/aspirations' do
      @title = 'Aspirations · Stephen Reid'
      erb :aspirations
    end
    
    get '/music' do
      erb :music
    end
    
    get '/tarot' do
      @title = 'Tarot · Stephen Reid'
      @og_image = "http://#{ENV['DOMAIN']}/images/tarotcards.jpg"
      erb :tarot
    end
    
    get '/gh' do
      redirect 'https://www.google.co.uk/maps/place/Greenhouse/@51.5529027,-0.0879017,15z/data=!4m2!3m1!1s0x0:0x9850520d11f22809'
    end   
            
    get '/:slug' do
      if @fragment = Fragment.find_by(slug: params[:slug], page: true)
        erb :page
      else
        pass
      end
    end  
     
  end         
end
