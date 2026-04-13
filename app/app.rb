module StephenReid
  class App < Padrino::Application
    register Padrino::Rendering
    register Padrino::Helpers
    register WillPaginate::Sinatra
    helpers Activate::ParamHelpers
    helpers Activate::NavigationHelpers

    use Honeybadger::Rack::UserFeedback
    use Honeybadger::Rack::UserInformer
    use Honeybadger::Rack::ErrorNotifier

    use Rack::Attack

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
      @stylesheet = params[:stylesheet] || 'dark'
      @cachebuster = Padrino.env == :development ? SecureRandom.uuid : ENV['HEROKU_SLUG_COMMIT']
      redirect "#{ENV['BASE_URI']}#{request.path}" if ENV['BASE_URI'] && (ENV['BASE_URI'] != "#{request.scheme}://#{request.env['HTTP_HOST']}")
      if params[:r]
        StephenReid::App.cache.clear
        redirect request.path
      end
      fix_params!
      Time.zone = 'London'
      @og_image = "https://api.apiflash.com/v1/urltoimage?access_key=#{ENV['APIFLASH_KEY']}&url=#{URI.encode_www_form_component("#{ENV['BASE_URI']}#{request.path}?no_modal=1")}&width=1280&height=672&ttl=2592000" unless Padrino.env == :development
    end

    error do
      erb :error, layout: :application
    end

    not_found do
      erb :not_found, layout: :application
    end

    get '/', cache: true do
      expires 1.hour.to_i
      @og_image = "#{ENV['BASE_URI']}/images/link.jpg"
      @og_desc = 'Technologist, facilitator and coach'
      @posts = Post.all(filter: "AND(
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

    get '/events', cache: true do
      expires 6.hours.to_i
      @title = 'Events'
      @container_class = 'container-fluid'
      erb :events
    end

    %w[films podcasts events speaking-engagements background].each do |r|
      get "/#{r}", cache: true do
        expires 6.hours.to_i
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

    get '/prompt', provides: :txt do
      Prompt.markdown(
        book_summaries: params[:book_summaries],
        notes_limit: params[:notes_limit],
        posts_limit: params[:posts_limit]
      ).join("\n\n")
    end

    get '/substack/notes', provides: :txt do
      SubstackNote.markdown_export(limit: params[:notes_limit])
    end

    get '/substack/posts', provides: :txt do
      SubstackPost.markdown_export(limit: params[:posts_limit])
    end

    get '/places' do
      KML_NS = { 'kml' => 'http://www.opengis.net/kml/2.2' }
      kml = Faraday.get('https://www.google.com/maps/d/kml?forcekml=1&mid=1QWAa8AYdFShGu6AgvK0ePUkgogGFEl8').body
      doc = Nokogiri::XML(kml)

      @places = doc.xpath('//kml:Folder', KML_NS).map do |folder|
        {
          name: folder.at_xpath('./kml:name', KML_NS).text,
          places: folder.xpath('.//kml:Placemark', KML_NS).map do |place|
            name = place.at_xpath('./kml:name', KML_NS).text
            coords = place.at_xpath('.//kml:coordinates', KML_NS).text.strip.split(',')
            {
              name: name,
              lat: coords[1],
              lng: coords[0]
            }
          end
        }
      end
      erb :places
    end

    get '/courses/:slug' do
      expires 6.hours.to_i
      @course = Course.all(filter: "{Slug} = '#{params[:slug]}'").first
      erb :'courses/course', layout: false
    end

    get '/books' do
      @title = 'Books'
      erb :books
    end

    get '/books/:slug', cache: true do
      expires 6.hours.to_i
      @book = Book.all(filter: "{Slug} = '#{params[:slug]}'").first || not_found
      redirect("https://www.goodreads.com/book/show/#{@book['Book Id']}") if @book['Summary'].blank?
      @title = @book['Title']
      erb :book
    end

    post '/telegram_webhook' do
      puts request.env['HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN']
      halt unless request.env['HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN'] == ENV['TELEGRAM_BOT_SECRET_TOKEN']
      puts json = JSON.parse(request.body.read)
      halt 200 unless json.dig('message', 'chat', 'id') == ENV['TELEGRAM_BOT_CHAT_ID'].to_i
      text = json['message']['text']
      if text.split.last =~ %r{^https?://}
        url = text.split.last
        text = text.split[0..-2].join(' ')
        iframely = JSON.parse(Faraday.get("https://iframe.ly/api/iframely?url=#{URI.encode_www_form_component(url)}&api_key=#{ENV['IFRAMELY_API_KEY']}").body)
        metadata = Post.extract_iframely_metadata(iframely)
        Post.post_to_bluesky(
          text,
          url: url,
          title: metadata[:title],
          description: metadata[:description],
          thumbnail: metadata[:thumbnail]
        )
        Post.post_to_x("#{text} #{url}".strip)
      else
        Post.post_to_bluesky(text)
        Post.post_to_x(text)
      end
      200
    end

    {
      '/z' => 'https://zoom.us/j/9082171779',
      '/cal' => 'https://cal.com/stephenreid',
      '/meet' => 'https://cal.com/stephenreid/meet',
      '/ooo' => 'https://app.cal.com/settings/my-account/out-of-office',
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
      '/maps' => '/life-as-practice',
      '/life-as-practice' => 'https://lifeaspractice.com/',
      '/technological-metamodernism' => 'https://stephenreid.substack.com/p/technological-metamodernism-course'
    }.each do |k, v|
      get k.to_s do
        redirect v
      end
    end
  end
end
