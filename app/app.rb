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

    use Rack::Session::Cookie, expire_after: 1.year.to_i, secret: ENV['SESSION_SECRET']
    set :public_folder, Padrino.root('app', 'assets')
    set :default_builder, 'ActivateFormBuilder'

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
      @substack_gallery = SubstackNote.recent_gallery_items(limit: 20)
      erb :home
    end

    get '/notes', cache: true do
      expires 1.hour.to_i
      @title = 'Notes'
      @substack_gallery = SubstackNote.recent_gallery_items(limit: 20)
      erb :notes
    end

    %w[background books coaching events films speaking-engagements].each do |r|
      get "/#{r}", cache: true do
        expires 6.hours.to_i
        @title = r.gsub('-', ' ').capitalize
        if r == 'coaching'
          @og_desc = 'What do you really want, and how can you move towards it?'
          @hide_subscribe = true
        end
        erb :"pages/#{r.underscore}"
      end
    end

    get '/courses/:slug' do
      @course = Course.all(filter: "{Slug} = '#{params[:slug]}'").first || not_found
      erb :course, layout: false
    end

    get '/books/:slug', cache: true do
      expires 6.hours.to_i
      @book = Book.all(filter: "{Slug} = '#{params[:slug]}'").first || not_found
      redirect("https://www.goodreads.com/book/show/#{@book['Book Id']}") if @book['Summary'].blank?
      @title = @book['Title']
      erb :book
    end

    get '/context', provides: :txt do
      ::Context.markdown(
        book_summaries: params[:book_summaries],
        notes_limit: params[:notes_limit],
        posts_limit: params[:posts_limit]
      ).join("\n\n")
    end

    get '/substack/notes', provides: :txt do
      SubstackNote.markdown_export(limit: params[:limit])
    end

    get '/substack/posts', provides: :txt do
      SubstackPost.markdown_export(limit: params[:limit])
    end

    get '/places' do
      kml_ns = { 'kml' => 'http://www.opengis.net/kml/2.2' }
      kml = Faraday.get('https://www.google.com/maps/d/kml?forcekml=1&mid=1QWAa8AYdFShGu6AgvK0ePUkgogGFEl8').body
      doc = Nokogiri::XML(kml)

      @places = doc.xpath('//kml:Folder', kml_ns).map do |folder|
        {
          name: folder.at_xpath('./kml:name', kml_ns).text,
          places: folder.xpath('.//kml:Placemark', kml_ns).map do |place|
            name = place.at_xpath('./kml:name', kml_ns).text
            coords = place.at_xpath('.//kml:coordinates', kml_ns).text.strip.split(',')
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
