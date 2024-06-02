module StephenReid
  class App < Padrino::Application
    register Padrino::Rendering
    register Padrino::Helpers
    register WillPaginate::Sinatra
    helpers Activate::ParamHelpers
    helpers Activate::NavigationHelpers

    register Padrino::Cache
    enable :caching unless Padrino.env == :development

    require 'sass/plugin/rack'
    Sass::Plugin.options[:template_location] = Padrino.root('app', 'assets', 'stylesheets')
    Sass::Plugin.options[:css_location] = Padrino.root('app', 'assets', 'stylesheets')
    use Sass::Plugin::Rack

    use Dragonfly::Middleware
    use Rack::Session::Cookie, expire_after: 1.year.to_i, secret: ENV['SESSION_SECRET']
    set :public_folder, Padrino.root('app', 'assets')
    set :default_builder, 'ActivateFormBuilder'

    Mail.defaults do
      delivery_method :smtp, {
        user_name: ENV['SMTP_USERNAME'],
        password: ENV['SMTP_PASSWORD'],
        address: ENV['SMTP_ADDRESS'],
        port: 587
      }
    end

    before do
      @hide_sponsors = true
      @stylesheet = params[:stylesheet] || 'dark'
      @cachebuster = Padrino.env == :development ? SecureRandom.uuid : ENV['HEROKU_SLUG_COMMIT']
      redirect "#{ENV['BASE_URI']}#{request.path}" if ENV['BASE_URI'] && (ENV['BASE_URI'] != "#{request.scheme}://#{request.env['HTTP_HOST']}")
      if params[:r]
        StephenReid::App.cache.clear
        redirect request.path
      end
      fix_params!
      Time.zone = 'London'
      @og_image = "https://api.apiflash.com/v1/urltoimage?access_key=#{ENV['APIFLASH_KEY']}&url=#{ENV['BASE_URI']}#{request.path}&width=1280&height=672&ttl=2592000" unless Padrino.env == :development
    end

    error do
      Airbrake.notify(env['sinatra.error'],
                      url: "#{ENV['BASE_URI']}#{request.path}",
                      params: params,
                      request: request.env.select { |_k, v| v.is_a?(String) },
                      session: session)
      erb :error, layout: :application
    end

    not_found do
      erb :not_found, layout: :application
    end

    get '/', cache: true do
      expires 1.hour.to_i
      @og_image = "#{ENV['BASE_URI']}/images/og-image.jpg"
      @og_desc = 'Technologist, facilitator and coach'
      @posts = Post.all(filter: "AND(
        IS_AFTER({Created at}, '#{1.month.ago.to_s(:db)}'),
        FIND('\"url\": ', {Iframely}) > 0,
        {Hide from homepage} != 1
      )", sort: { 'Created at' => 'desc' })
      erb :about
    end

    get '/sign_in/:code' do
      if params[:code].to_i == ENV['SIGN_IN_CODE']
        session[:account_id] = Account.find_by(admin: true)
        flash.now[:success] = 'Signed in!'
      end
      redirect '/'
    end

    %w[films podcasts events speaking-engagements].each do |r|
      get "/#{r}", cache: true do
        expires 1.hour.to_i
        @title = r.gsub('-', ' ').capitalize
        erb :"#{r.underscore}"
      end
    end

    {
      '/z' => 'https://zoom.us/j/9082171779',
      '/cal' => 'https://cal.com/stephenreid',
      '/meet' => 'https://cal.com/stephenreid/meet',
      '/15' => 'https://cal.com/stephenreid/15',
      '/30' => 'https://cal.com/stephenreid/30',
      '/60' => 'https://cal.com/stephenreid/60',
      '/about' => '/',
      '/link' => '/',
      '/training' => '/about',
      '/bio' => '/about',
      '/darknet' => 'https://dark.fail/',
      '/why-use-the-darknet' => 'https://dark.fail/',
      '/books-videos' => '/knowledgegraph',
      '/featured' => '/knowledgegraph',
      '/recommended' => '/knowledgegraph',
      '/maps' => '/life-as-practice'
    }.each do |k, v|
      get k.to_s do
        redirect v
      end
    end

    get '/to/:slug' do
      @product = Product.all(filter: "{Slug} = '#{params[:slug]}'").first || not_found
      redirect @product['URL']
    end

    get '/p/:slug' do
      @product = Product.all(filter: "{Slug} = '#{params[:slug]}'").first || not_found
      @url = @product['URL']
      erb :redirect
    end

    get '/r/:slug' do
      @link = Link.all(filter: "{Slug} = '#{params[:slug]}'").first || not_found
      @url = @link['URL']
      erb :redirect
    end

    get '/ai-consulting' do
      @title = 'AI consulting'
      @og_desc = 'Hire me to help you with your AI project'
      @hide_subscribe = true
      erb :ai_consulting
    end

    get '/facilitation' do
      @title = 'Group facilitation'
      @og_desc = 'Hire me to facilitate your group process'
      @hide_subscribe = true
      erb :facilitation
    end

    get '/coaching' do
      @title = 'Coaching'
      @og_desc = 'What do you really want, and how can you move towards it?'
      @hide_subscribe = true
      erb :coaching
    end

    get '/lunarpunk-dreams' do
      redirect '/blog/2022/09/30/beyond-privacy-the-seven-darknesses-of-lunarpunk.html'
    end

    get '/substack', provides: :txt do
      substack_posts
    end

    get '/prompt', provides: :txt do
      "#{BlogPost.prompt(book_summaries: params[:book_summaries]).join("\n\n")}\n\n#{substack_posts}"
    end

    ##############################

    get '/software/update' do
      Software.iframely
      redirect '/software?r=1'
    end

    get '/films/update' do
      Film.iframely
      redirect '/films?r=1'
    end

    get '/master-lover-course' do
      send_file "#{Padrino.root}/app/markdown/master-lover-course.html"
    end
  end
end
