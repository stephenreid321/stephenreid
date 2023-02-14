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

    set :sessions, expire_after: 1.year
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
      @og_desc = 'Teacher, technologist and coach'
      erb :about
    end

    get '/sign_in/:code' do
      if params[:code].to_i == ENV['SIGN_IN_CODE']
        session[:account_id] = Account.find_by(admin: true)
        flash.now[:success] = 'Signed in!'        
      end
      redirect '/'
    end

    %w[books podcasts software discord tarot events svenska-ord svensk-grammatik diet speaking-engagements].each do |r|
      get "/#{r}", cache: true do
        expires 1.hour.to_i
        @title = r.gsub('-', ' ').capitalize
        erb :"#{r.underscore}"
      end
    end

    get '/coaching' do
      @title = 'Coaching'
      @og_desc = 'What do you really want, and how can you move towards it?'
      @hide_subscribe = true
      erb :coaching
    end

    get '/lunarpunk-dreams' do
      @title = 'Lunarpunk Dreams'
      @og_desc = 'Lunarpunk is what happens when the sun goes down in a Solarpunk village/town/city.'
      @og_image = "#{ENV['BASE_URI']}/images/lunarpunk_dreams_horizontal.png"
      erb :lunarpunk_dreams
    end

    {
      '/calendly' => 'https://calendly.com/stephenreid321',
      '/1' => 'https://calendly.com/stephenreid321/1-min-call',
      '/5' => 'https://calendly.com/stephenreid321/5-min-call',
      '/15' => 'https://calendly.com/stephenreid321/15-min-call',
      '/30' => 'https://calendly.com/stephenreid321/30-min-call',
      '/55' => 'https://calendly.com/stephenreid321/60-min-call',
      '/60' => 'https://calendly.com/stephenreid321/60-min-call',
      '/90' => 'https://calendly.com/stephenreid321/90-min-call',
      '/120' => 'https://calendly.com/stephenreid321/120-min-call',
      '/15p' => 'https://calendly.com/stephenreid321/priority-15-min-call',
      '/30p' => 'https://calendly.com/stephenreid321/priority-30-min-call',
      '/60p' => 'https://calendly.com/stephenreid321/priority-60-min-call',
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
    }.each { |k, v| get k.to_s do; redirect v; end }

    get '/substack' do
      @from = params[:from] ? Date.parse(params[:from]) : Date.today
      erb :format_for_substack
    end

    get '/pocket' do
      # code = Pocket.get_code(:redirect_uri => 'https://stephenreid.net')
      # redirect Pocket.authorize_url(:code => code, :redirect_uri => 'https://stephenreid.net')
      # Pocket.get_result(code, :redirect_uri => 'https://stephenreid.net')
      erb :process_pocket
    end

    get '/pocket/:id' do
      client = Pocket.client(access_token: ENV['POCKET_ACCESS_TOKEN'])
      url = client.retrieve(detailType: :complete)['list'][params[:id]]['resolved_url']
      client.modify([{ action: 'delete', item_id: params[:id] }])
      redirect url
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

    get '/software/update' do
      agent = Mechanize.new
      Software.all(filter: "AND({Featured} = 1, {Description} = '')").each do |software|
        result = agent.get("https://iframe.ly/api/iframely?url=#{software['URL']}&api_key=#{ENV['IFRAMELY_API_KEY']}")
        json = JSON.parse(result.body.force_encoding('UTF-8'))
        software['Description'] = json['meta']['description']
        software['Images'] = [{ url: json['links']['thumbnail'].first['href'] }] if json['links']['thumbnail'] && !software['Images']
        software.save
      end
      redirect '/software?r=1'
    end

    get '/master-lover-course' do
      send_file "#{Padrino.root}/app/markdown/master-lover-course.html"
    end
  end
end
