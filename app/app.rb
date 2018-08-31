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
      @og_desc = 'Social entrepreneur, activist and public speaker'
      @og_image = (Preview.find_by(url: "http://#{ENV['DOMAIN']}#{request.path}") || Preview.find_by(url: "http://#{ENV['DOMAIN']}/")).try(:image).try(:url)
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
      erb :home
    end

    get '/bio' do
      redirect '/'
    end

    get '/podcasts' do
      redirect '/podcast'
    end

    get '/podcast' do
      @title = 'Podcast'
      erb :podcast
    end

    get '/calendar' do
      @title = 'Calendar'
      erb :calendar
    end

    get '/places' do
      @title = 'Places'
      if params[:map]
        @places = Organisation.all
        @places = @places.where(category: 'upcoming') if params[:plans]
        @view = 'map'
        erb :map
      else
        erb :places
      end
    end
        
    get '/following' do
      @title = 'Following'
      erb :following
    end        

    get '/habits' do
      @title = 'Habits'
      erb :habits
    end

    get '/music' do
      erb :music
    end

    get '/tarot' do
      @title = 'Tarot'
      @og_image = "http://#{ENV['DOMAIN']}/images/tarotcards.jpg"
      erb :tarot
    end
    
    get '/books' do
      @title = 'Books'
      erb :books
    end

    get '/gh' do
      redirect 'https://www.google.co.uk/maps/place/Greenhouse/@51.5529027,-0.0879017,15z/data=!4m2!3m1!1s0x0:0x9850520d11f22809'
    end

    get '/art' do
      @title = 'Art'
      erb :art
    end

    get '/art-block' do
      partial :art_block, :locals => {:title => params[:title], :link => params[:link], :image_url => params[:image_url]}
    end

    get '/arena' do
      erb :arena
    end

    get '/block' do
      partial :block, :locals => {:title => params[:title], :link => params[:link], :image_url => params[:image_url]}
    end

    get '/darknet' do
      @title = 'Step-by-step guide to the darknet'
      @og_desc = 'A step-by-step guide to using a darknet marketplace. Start to finish, it takes a couple of hours.'
      @og_image = "http://#{ENV['DOMAIN']}/images/marketplace/tor.png"
      erb :darknet
    end

    get '/why-use-the-darknet' do
      @title = 'Why use the darknet to obtain psychedelics?'
      @og_desc = 'Why using the darknet to obtain psychedelics is better for you and better for society'
      erb :why_use_the_darknet
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
