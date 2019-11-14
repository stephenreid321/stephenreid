module ActivateApp
  class App < Padrino::Application
    register Padrino::Rendering
    register Padrino::Helpers
    register WillPaginate::Sinatra
    helpers Activate::DatetimeHelpers
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
      if params[:r]
        ActivateApp::App.cache.clear
        redirect request.path
      end      
      fix_params!
      Time.zone = 'London'
      @og_desc = 'Transdisciplinary thinker, cultural changemaker and metamodern mystic'
      @og_image = "http://#{ENV['DOMAIN']}/images/link4.png"
    end

    error do
      Airbrake.notify(env['sinatra.error'], :session => session)
      erb :error, :layout => :application
    end

    not_found do
      erb :not_found, :layout => :application
    end

    get '/', :cache => true do
      expires 1.hour.to_i
      @full_network = true
      @posts = Post.all(filter: "AND(
        IS_AFTER({Created at}, '#{1.month.ago.to_s(:db)}'),
        FIND('\"url\": ', {Iframely}) > 0
      )", sort: { "Created at" => "desc" }, paginate: false)    
      erb :home
    end
    
    get '/search' do      
      if params[:q]
        @title = params[:q]
        @posts = Post.all(filter: "OR(
          FIND(LOWER('#{params[:q]}'), LOWER({Title})) > 0,
          FIND(LOWER('#{params[:q]}'), LOWER({Body})) > 0,
          FIND(LOWER('#{params[:q]}'), LOWER({Iframely})) > 0
        )", sort: { "Created at" => "desc" })       
      else
        @full_network = true
        @posts = Post.all(filter: "AND(
        IS_AFTER({Created at}, '#{1.month.ago.to_s(:db)}'),
        FIND('\"url\": ', {Iframely}) > 0
      )", sort: { "Created at" => "desc" }, paginate: false)    
      end
      erb :search
    end
    
    get '/terms/:term', :cache => true do
      expires 1.hour.to_i
      @posts = Post.all(filter: "FIND(', #{params[:term]},', {Terms joined}) > 0", sort: { "Created at" => "desc" })
      erb :search
    end
    
    get '/terms/:source_id/:sink_id', :cache => true do
      expires 1.hour.to_i
      @source = Term.find(params[:source_id])
      @sink = Term.find(params[:sink_id])
      @posts = Post.all(filter: "AND(
        FIND(', #{@source['Name']},', {Terms joined}) > 0,
        FIND(', #{@sink['Name']},', {Terms joined}) > 0
        )", sort: { "Created at" => "desc" })        
      erb :search
    end
    
    get '/organisations/:organisation', :cache => true do
      expires 1.hour.to_i
      @posts = Post.all(filter: "{Organisation} = '#{params[:organisation]}'", sort: { "Created at" => "desc" })                        
      erb :search
    end
    
    get '/feed', :provides => :rss, :cache => true do
      expires 1.hour.to_i
      @posts = Post.all(filter: "AND(
        IS_AFTER({Created at}, '#{1.month.ago.to_s(:db)}'),
        FIND('\"url\": ', {Iframely}) > 0
      )", sort: { "Created at" => "desc" }, paginate: false)     
      RSS::Maker.make("atom") do |maker|
        maker.channel.author = "Stephen Reid"
        maker.channel.updated = Time.now.to_s
        maker.channel.about = "http://stephenreid.net"
        maker.channel.title = "Stephen Reid"

        @posts.each { |post|
          maker.items.new_item do |item|
            item.link = post['Link']
            item.title = post['Title']
            item.description = post['Body']
            item.updated = post['Created at']
          end
        }
      end.to_s            
    end
    
    get '/bio', :cache => true do
      @title = 'Biography'
      erb :bio
    end
    
    get '/donate', :cache => true do
      @title = 'Donate'
      erb :donate
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
    
    get '/diet', :cache => true do
      @title = 'Diet'
      erb :diet
    end    

    get '/tarot', :cache => true do
      @title = 'Tarot'
      @og_image = "http://#{ENV['DOMAIN']}/images/the-magician.jpg"
      erb :tarot
    end
    
    get '/products', :cache => true do
      @title = 'Recommended products'
      erb :products
    end    
    
    get '/books', :cache => true do
      @title = 'Books'
      erb :books
    end 
    
    
    
    
    
    
    get '/posts/:id', :cache => true do
      @post = begin; Post.find(params[:id]); rescue; not_found; end
      @json = JSON.parse(@post['Iframely'])
      @title = @post['Title']
      @og_desc = @post['Body']
      if @json['links'] && @json['links']['thumbnail']
        @og_image = @json['links']['thumbnail'].first['href']
      end
      erb :post    
    end 
    
    get '/posts/:id/iframely' do
      @post = begin; Post.find(params[:id]); rescue; not_found; end
      agent = Mechanize.new
      result = agent.get("https://iframe.ly/api/iframely?url=#{@post['Link'].split('#').first}&api_key=#{ENV['IFRAMELY_API_KEY']}")
      @post['Iframely'] = result.body.force_encoding("UTF-8")
      @post.save
      redirect "/posts/#{params[:id]}"
    end
    
    get '/posts/:id/tagify' do
      @post = begin; Post.find(params[:id]); rescue; not_found; end      
      if !@post['Title']
        @json = JSON.parse(post['Iframely'])
        @post['Title'] = @json['meta']['title']
        @post['Body'] = @json['meta']['description']
        @post.save
      end
      @post.tagify   
      redirect "/posts/#{params[:id]}"
    end   
    
    get '/terms/update' do
      Term.all.each { |term|
        if !term['Posts']
          term.tagify
          term.create_edges
        end
      }
      200
    end
        
    get '/terms/:id/update' do
      @term = begin; Term.find(params[:id]); rescue; not_found; end      
      @term.tagify   
      @term.create_edges
      redirect "/terms/#{@term['Name']}"
    end
       
    get '/organisations/:id/update' do
      @organisation = begin; Organisation.find(params[:id]); rescue; not_found; end      
      @organisation.tagify   
      redirect "/organisations/#{@organisation['Name']}"
    end      
    
    
    
      
    get '/blog', :cache => true do
      @blog_posts = BlogPost.all(sort: { "Published at" => "desc" })
      erb :blog
    end   
    
    get '/blog/feed', :provides => :rss, :cache => true do
      @blog_posts = BlogPost.all(sort: { "Published at" => "desc" })
      RSS::Maker.make("atom") do |maker|
        maker.channel.author = "Stephen Reid"
        maker.channel.updated = Time.now.to_s
        maker.channel.about = "http://stephenreid.net"
        maker.channel.title = "Stephen Reid"

        @blog_posts.each { |blog_post|
          maker.items.new_item do |item|
            item.link = "https://#{ENV['DOMAIN']}/blog/#{blog_post['Slug']}"
            item.title = blog_post['Title']
            item.description = blog_post['Summary']
            item.updated = blog_post['Published at']
          end
        }
      end.to_s            
    end    

    get '/blog/:slug', :cache => true do
      @blog_post = BlogPost.all(filter: "{Slug} = '#{params[:slug]}'").first
      @title = @blog_post['Title']
      @og_desc = @blog_post['Summary']
      @og_image = @blog_post['Attachments'].first['url']
      erb :blog_post
    end   
    
    
    
    
    
    get '/stats' do
      @stops = ["0o", "0s", "3a", "3b", "3d", "6b", "6o", "a", "A", "a1", "a2", "a3", "a4", "ab", "able", "about", "above", "abst", "ac", "accordance", "according", "accordingly", "across", "act", "actually", "ad", "added", "adj", "ae", "af", "affected", "affecting", "after", "afterwards", "ag", "again", "against", "ah", "ain", "aj", "al", "all", "allow", "allows", "almost", "alone", "along", "already", "also", "although", "always", "am", "among", "amongst", "amoungst", "amount", "an", "and", "announce", "another", "any", "anybody", "anyhow", "anymore", "anyone", "anyway", "anyways", "anywhere", "ao", "ap", "apart", "apparently", "appreciate", "approximately", "ar", "are", "aren", "arent", "arise", "around", "as", "aside", "ask", "asking", "at", "au", "auth", "av", "available", "aw", "away", "awfully", "ax", "ay", "az", "b", "B", "b1", "b2", "b3", "ba", "back", "bc", "bd", "be", "became", "been", "before", "beforehand", "beginnings", "behind", "below", "beside", "besides", "best", "between", "beyond", "bi", "bill", "biol", "bj", "bk", "bl", "bn", "both", "bottom", "bp", "br", "brief", "briefly", "bs", "bt", "bu", "but", "bx", "by", "c", "C", "c1", "c2", "c3", "ca", "call", "came", "can", "cannot", "cant", "cc", "cd", "ce", "certain", "certainly", "cf", "cg", "ch", "ci", "cit", "cj", "cl", "clearly", "cm", "cn", "co", "com", "come", "comes", "con", "concerning", "consequently", "consider", "considering", "could", "couldn", "couldnt", "course", "cp", "cq", "cr", "cry", "cs", "ct", "cu", "cv", "cx", "cy", "cz", "d", "D", "d2", "da", "date", "dc", "dd", "de", "definitely", "describe", "described", "despite", "detail", "df", "di", "did", "didn", "dj", "dk", "dl", "do", "does", "doesn", "doing", "don", "done", "down", "downwards", "dp", "dr", "ds", "dt", "du", "due", "during", "dx", "dy", "e", "E", "e2", "e3", "ea", "each", "ec", "ed", "edu", "ee", "ef", "eg", "ei", "eight", "eighty", "either", "ej", "el", "eleven", "else", "elsewhere", "em", "en", "end", "ending", "enough", "entirely", "eo", "ep", "eq", "er", "es", "especially", "est", "et", "et-al", "etc", "eu", "ev", "even", "ever", "every", "everybody", "everyone", "everything", "everywhere", "ex", "exactly", "example", "except", "ey", "f", "F", "f2", "fa", "far", "fc", "few", "ff", "fi", "fifteen", "fifth", "fify", "fill", "find", "fire", "five", "fix", "fj", "fl", "fn", "fo", "followed", "following", "follows", "for", "former", "formerly", "forth", "forty", "found", "four", "fr", "from", "front", "fs", "ft", "fu", "full", "further", "furthermore", "fy", "g", "G", "ga", "gave", "ge", "get", "gets", "getting", "gi", "give", "given", "gives", "giving", "gj", "gl", "go", "goes", "going", "gone", "got", "gotten", "gr", "greetings", "gs", "gy", "h", "H", "h2", "h3", "had", "hadn", "happens", "hardly", "has", "hasn", "hasnt", "have", "haven", "having", "he", "hed", "hello", "help", "hence", "here", "hereafter", "hereby", "herein", "heres", "hereupon", "hes", "hh", "hi", "hid", "hither", "hj", "ho", "hopefully", "how", "howbeit", "however", "hr", "hs", "http", "hu", "hundred", "hy", "i2", "i3", "i4", "i6", "i7", "i8", "ia", "ib", "ibid", "ic", "id", "ie", "if", "ig", "ignored", "ih", "ii", "ij", "il", "im", "immediately", "in", "inasmuch", "inc", "indeed", "index", "indicate", "indicated", "indicates", "information", "inner", "insofar", "instead", "interest", "into", "inward", "io", "ip", "iq", "ir", "is", "isn", "it", "itd", "its", "iv", "ix", "iy", "iz", "j", "J", "jj", "jr", "js", "jt", "ju", "just", "k", "K", "ke", "keep", "keeps", "kept", "kg", "kj", "km", "ko", "l", "L", "l2", "la", "largely", "last", "lately", "later", "latter", "latterly", "lb", "lc", "le", "least", "les", "less", "lest", "let", "lets", "lf", "like", "liked", "likely", "line", "little", "lj", "ll", "ln", "lo", "look", "looking", "looks", "los", "lr", "ls", "lt", "ltd", "m", "M", "m2", "ma", "made", "mainly", "make", "makes", "many", "may", "maybe", "me", "meantime", "meanwhile", "merely", "mg", "might", "mightn", "mill", "million", "mine", "miss", "ml", "mn", "mo", "more", "moreover", "most", "mostly", "move", "mr", "mrs", "ms", "mt", "mu", "much", "mug", "must", "mustn", "my", "n", "N", "n2", "na", "name", "namely", "nay", "nc", "nd", "ne", "near", "nearly", "necessarily", "neither", "nevertheless", "new", "next", "ng", "ni", "nine", "ninety", "nj", "nl", "nn", "no", "nobody", "non", "none", "nonetheless", "noone", "nor", "normally", "nos", "not", "noted", "novel", "now", "nowhere", "nr", "ns", "nt", "ny", "o", "O", "oa", "ob", "obtain", "obtained", "obviously", "oc", "od", "of", "off", "often", "og", "oh", "oi", "oj", "ok", "okay", "ol", "old", "om", "omitted", "on", "once", "one", "ones", "only", "onto", "oo", "op", "oq", "or", "ord", "os", "ot", "otherwise", "ou", "ought", "our", "out", "outside", "over", "overall", "ow", "owing", "own", "ox", "oz", "p", "P", "p1", "p2", "p3", "page", "pagecount", "pages", "par", "part", "particular", "particularly", "pas", "past", "pc", "pd", "pe", "per", "perhaps", "pf", "ph", "pi", "pj", "pk", "pl", "placed", "please", "plus", "pm", "pn", "po", "poorly", "pp", "pq", "pr", "predominantly", "presumably", "previously", "primarily", "probably", "promptly", "proud", "provides", "ps", "pt", "pu", "put", "py", "q", "Q", "qj", "qu", "que", "quickly", "quite", "qv", "r", "R", "r2", "ra", "ran", "rather", "rc", "rd", "re", "readily", "really", "reasonably", "recent", "recently", "ref", "refs", "regarding", "regardless", "regards", "related", "relatively", "research-articl", "respectively", "resulted", "resulting", "results", "rf", "rh", "ri", "right", "rj", "rl", "rm", "rn", "ro", "rq", "rr", "rs", "rt", "ru", "run", "rv", "ry", "s", "S", "s2", "sa", "said", "saw", "say", "saying", "says", "sc", "sd", "se", "sec", "second", "secondly", "section", "seem", "seemed", "seeming", "seems", "seen", "sent", "seven", "several", "sf", "shall", "shan", "shed", "shes", "show", "showed", "shown", "showns", "shows", "si", "side", "since", "sincere", "six", "sixty", "sj", "sl", "slightly", "sm", "sn", "so", "some", "somehow", "somethan", "sometime", "sometimes", "somewhat", "somewhere", "soon", "sorry", "sp", "specifically", "specified", "specify", "specifying", "sq", "sr", "ss", "st", "still", "stop", "strongly", "sub", "substantially", "successfully", "such", "sufficiently", "suggest", "sup", "sure", "sy", "sz", "t", "T", "t1", "t2", "t3", "take", "taken", "taking", "tb", "tc", "td", "te", "tell", "ten", "tends", "tf", "th", "than", "thank", "thanks", "thanx", "that", "thats", "the", "their", "theirs", "them", "themselves", "then", "thence", "there", "thereafter", "thereby", "thered", "therefore", "therein", "thereof", "therere", "theres", "thereto", "thereupon", "these", "they", "theyd", "theyre", "thickv", "thin", "think", "third", "this", "thorough", "thoroughly", "those", "thou", "though", "thoughh", "thousand", "three", "throug", "through", "throughout", "thru", "thus", "ti", "til", "tip", "tj", "tl", "tm", "tn", "to", "together", "too", "took", "top", "toward", "towards", "tp", "tq", "tr", "tried", "tries", "truly", "try", "trying", "ts", "tt", "tv", "twelve", "twenty", "twice", "two", "tx", "u", "U", "u201d", "ue", "ui", "uj", "uk", "um", "un", "under", "unfortunately", "unless", "unlike", "unlikely", "until", "unto", "uo", "up", "upon", "ups", "ur", "us", "used", "useful", "usefully", "usefulness", "using", "usually", "ut", "v", "V", "va", "various", "vd", "ve", "very", "via", "viz", "vj", "vo", "vol", "vols", "volumtype", "vq", "vs", "vt", "vu", "w", "W", "wa", "was", "wasn", "wasnt", "way", "we", "wed", "welcome", "well", "well-b", "went", "were", "weren", "werent", "what", "whatever", "whats", "when", "whence", "whenever", "where", "whereafter", "whereas", "whereby", "wherein", "wheres", "whereupon", "wherever", "whether", "which", "while", "whim", "whither", "who", "whod", "whoever", "whole", "whom", "whomever", "whos", "whose", "why", "wi", "widely", "with", "within", "without", "wo", "won", "wonder", "wont", "would", "wouldn", "wouldnt", "www", "x", "X", "x1", "x2", "x3", "xf", "xi", "xj", "xk", "xl", "xn", "xo", "xs", "xt", "xv", "xx", "y", "Y", "y2", "yes", "yet", "yj", "yl", "you", "youd", "your", "youre", "yours", "yr", "ys", "yt", "z", "Z", "zero", "zi", "zz"]
      words = ''
      hosts = []
      Post.all.each { |post|
        post_words = ''
        json = JSON.parse(post['Iframely'])
        post_words += "#{post['Title']} "
        post_words += "#{post['Body']} " if post['Body'] && !post['Body'].include?('use cookies') && !post['Body'].include?('use of cookies')
        if json['meta']
          post_words += "#{json['meta']['title']} " if json['meta']['title']
          post_words += "#{json['meta']['description']} " if json['meta']['description']
          post_words += "#{json['meta']['category']} " if json['meta']['category']
          post_words += "#{json['meta']['keywords'].split(',').join(' ')} " if json['meta']['keywords']
        end
        words += post_words.gsub('. ','' ).gsub(', ',' ').gsub('! ',' ').split(' ').uniq.join(' ')
        hosts << URI(post['Link']).host.gsub('www.','')                
      }      
      @frequency = words.scan(/\w+/).reduce(Hash.new(0)){|res,w| res[w.downcase]+=1;res}      
      @host_frequency = hosts.each_with_object(Hash.new(0)){|key,hash| hash[key] += 1}
      erb :stats
    end
        

   
    get '/to/:slug' do
      @url = Product.all(filter: "{Slug} = '#{params[:slug]}'").first['URL']
      redirect @url
    end
    
    get '/p/:slug' do
      @url = Product.all(filter: "{Slug} = '#{params[:slug]}'").first['URL']
      erb :redirect
    end
    
    get '/r/:slug' do
      @url = Link.all(filter: "{Slug} = '#{params[:slug]}'").first['URL']
      erb :redirect
    end    
                   
    get '/places-plans' do
      @title = 'Places & Plans'
      erb :places
    end      
        
    get '/link' do
      redirect 'http://stephenreid.net'
    end
    
    get '/substack' do
      @from = params[:from] ? Date.parse(params[:from]) : Date.today
      erb :substack
    end   
    
    
    
    
    
               
    get '/ps' do
      redirect 'https://www.google.com/maps/place/The+Psychedelic+Society/@51.547382,-0.0449452,17z/data=!4m12!1m6!3m5!1s0x48761dff684f311b:0xa492a62a16335e19!2sThe+Psychedelic+Society!8m2!3d51.547382!4d-0.0427565!3m4!1s0x48761dff684f311b:0xa492a62a16335e19!8m2!3d51.547382!4d-0.0427565'
    end    
        
    get '/gh' do
      redirect 'https://www.google.com/maps/place/Greenhouse/@51.5529027,-0.0879017,15z/data=!4m2!3m1!1s0x0:0x9850520d11f22809?sa=X&ved=2ahUKEwjDvsas2MDhAhVlRRUIHS9_B5MQ_BIwDnoECA0QCA'
    end
    
    
    
    get '/training' do
      redirect '/bio'
    end        
    
    get '/darknet' do #, :cache => true do
      redirect 'https://dark.fail/'
    end

    get '/why-use-the-darknet' do #, :cache => true do
      redirect 'https://dark.fail/'
    end
        
    get '/podcasts' do
      redirect '/podcast'
    end        
            
    get '/books-videos' do
      redirect '/'
    end    
    
    get '/featured' do
      redirect '/'
    end
    
    get '/recommended' do
      redirect '/'
    end

  end
end
