module StephenReid
  class App < Padrino::Application
    register Padrino::Rendering
    register Padrino::Helpers
    register WillPaginate::Sinatra
    helpers Activate::ParamHelpers
    helpers Activate::NavigationHelpers

    if Padrino.env == :production
      register Padrino::Cache
      enable :caching
    end

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
      @cachebuster = Padrino.env == :development ? SecureRandom.uuid : ENV['HEROKU_SLUG_COMMIT']
      redirect "#{ENV['BASE_URI']}#{request.path}" if ENV['BASE_URI'] && (ENV['BASE_URI'] != "#{request.scheme}://#{request.env['HTTP_HOST']}")
      if Padrino.env == :production && params[:r]
        StephenReid::App.cache.clear
        redirect request.path
      end
      fix_params!
      Time.zone = 'London'
      @og_desc = 'Co-operative technologist and cultural changemaker'
      @og_image = "#{ENV['BASE_URI']}/images/link6.jpeg"
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
      erb :about
    end

    (
      %w[services podcast books] +
        %w[donate calendar habits tarot]
    ).each do |r|
      get "/#{r}", cache: true do
        @title = r.capitalize
        erb :"#{r}"
      end
    end

    get '/tao-te-ching' do
      @title = 'Tao Te Ching'
      @favicon = 'tao-sq.png'
      erb :tao
    end

    get '/tao-te-ching/:i' do
      @title = "Verse #{params[:i]} · Tao Te Ching"
      @favicon = 'tao-sq.png'
      erb :tao
    end

    get '/products', cache: true do
      @title = 'Recommended products'
      erb :products
    end

    get '/places-plans' do
      @title = 'Places & Plans'
      erb :places
    end

    get '/software', cache: true do
      @title = 'Software'
      erb :software
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

    get '/groups', cache: true do
      @title = 'Groups'
      erb :groups
    end

    get '/groups/update' do
      agent = Mechanize.new
      agent.user_agent_alias = 'Android'
      Group.all(filter: "AND(
        FIND(', key,', {Interests joined}) > 0,
        {Facebook URL} != ''
      )").each do |group|
        next if group['Images']

        begin
          page = agent.get(group['Facebook URL'])
          image_url = page.search('._3m1l i.img')[0]['style'].split("('")[1].split("')")[0].gsub('\3a ', ':').gsub('\3d ', '=').gsub('\26 ', '&')
          group['Images'] = [{ url: image_url }]
          group.save
        rescue StandardError
          true
        end
      end
      redirect '/groups?r=1'
    end

    get '/substack' do
      @from = params[:from] ? Date.parse(params[:from]) : Date.today
      erb :substack
    end

    get '/diff' do
      erb :diff
    end

    get '/pocket' do
      # code = Pocket.get_code(:redirect_uri => 'https://stephenreid.net')
      # redirect Pocket.authorize_url(:code => code, :redirect_uri => 'https://stephenreid.net')
      # Pocket.get_result(code, :redirect_uri => 'https://stephenreid.net')
      erb :pocket
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

    get '/master-lover-course' do
      send_file "#{Padrino.root}/app/markdown/master-lover-course.html"
    end

    {
      '/calendly' => 'https://calendly.com/stephenreid321',
      '/30' => 'https://calendly.com/stephenreid321/30-min-call',
      '/55' => 'https://calendly.com/stephenreid321/55-min-call',
      '/90' => 'https://calendly.com/stephenreid321/90-min-call',
      '/120' => 'https://calendly.com/stephenreid321/120-min-call',
      '/about' => '/',
      '/link' => '/',
      '/training' => '/about',
      '/bio' => '/about',
      '/darknet' => 'https://dark.fail/',
      '/why-use-the-darknet' => 'https://dark.fail/',
      '/podcasts' => '/podcast',
      '/books-videos' => '/knowledgegraph',
      '/featured' => '/knowledgegraph',
      '/recommended' => '/knowledgegraph'
    }.each { |k, v| get k.to_s do; redirect v; end }
  end
end
