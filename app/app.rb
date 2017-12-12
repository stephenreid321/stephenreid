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
        :user_name => ENV['MANDRILL_USERNAME'],
        :password => ENV['MANDRILL_APIKEY'],
        :address => "smtp.mandrillapp.com",
        :port => 587
      }   
    end 
       
    before do
      redirect "http://#{ENV['DOMAIN']}#{request.path}" if ENV['DOMAIN'] and request.env['HTTP_HOST'] != ENV['DOMAIN']
      Time.zone = current_account.time_zone if current_account and current_account.time_zone    
      fix_params!
      @_params = params; def params; @_params; end # force controllers to inherit the fixed params
      @title = 'Stephen Reid'
      @og_desc = 'Director of the Psychedelic Society and freelance digital creative'
      @og_image = "http://#{ENV['DOMAIN']}/images/speaking.jpg"
    end        
                
    error do
      Airbrake.notify(env['sinatra.error'], :session => session)
      erb :error, :layout => :application
    end        
    
    not_found do
      erb :not_found, :layout => :application
    end
    
    get :home, :map => '/' do
      erb :home
    end
    
    get '/gh' do
      redirect 'https://www.google.co.uk/maps/place/Greenhouse/@51.5529027,-0.0879017,15z/data=!4m2!3m1!1s0x0:0x9850520d11f22809'
    end
    
    get '/crypto' do      
      erb :crypto
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
