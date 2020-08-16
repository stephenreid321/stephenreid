StephenReid::App.controller do
      
  get '/knowledgegraph', :cache => true do
    @title = 'Knowledgegraph'
    expires 1.hour.to_i
    @full_network = true
    @posts = Post.all(filter: "AND(
        IS_AFTER({Created at}, '#{1.month.ago.to_s(:db)}'),
        FIND('\"url\": ', {Iframely}) > 0
      )", sort: { "Created at" => "desc" }, paginate: false)
    erb :links
  end    
  
  get '/search' do      
    if params[:q]
      @q = params[:q]
      if @q.include?('after:')
        @q, @after = @q.split('after:')
      end
      @title = @q.empty? ? "Posts since #{@after}" : @q
      @posts = Post.all(filter: "AND(
        #{%Q{IS_AFTER({Created at}, '#{Date.parse(@after).to_s(:db)}'),} if @after}
          OR(
            FIND(LOWER('#{@q}'), LOWER({Title})) > 0,
            FIND(LOWER('#{@q}'), LOWER({Body})) > 0,
            FIND(LOWER('#{@q}'), LOWER({Iframely})) > 0
          )
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
        json = JSON.parse(post['Iframely'])      
        maker.items.new_item do |item|
          item.link = post['Link']
          item.title = post['Title']
          item.description = json['meta']['description'].truncate(150)
          item.updated = post['Created at']
        end
      }
    end.to_s            
  end
  
  
  
  
      
  get '/posts/:id', :cache => true do
    @post = begin; Post.find(params[:id]); rescue; not_found; end
    @json = JSON.parse(@post['Iframely'])
    @full_title = @post['Title']
    @og_desc = @json['meta']['description']        
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
    200
  end
    
  get '/posts/:id/tagify' do
    @post = begin; Post.find(params[:id]); rescue; not_found; end      
    if !@post['Title']
      @json = JSON.parse(@post['Iframely'])
      @post['Title'] = @json['meta']['title']
      @post['Body'] = @json['meta']['description']
      @post.save
    end
    @post.tagify   
    200
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
  
  get '/terms/tagify' do
    post_ids = []
    Term.all.each { |term|
      if !term['Posts']
        post_ids += Post.all(filter: "
        OR(
          FIND(LOWER('#{term['Name']}'), LOWER({Title})) > 0,
          FIND(LOWER('#{term['Name']}'), LOWER({Body})) > 0,
          FIND(LOWER('#{term['Name']}'), LOWER({Iframely})) > 0
        )
          ", sort: { "Created at" => "desc" }).map(&:id)
      end
    }
    post_ids = post_ids.uniq
    if post_ids.length > 0
      puts "#{c = post_ids.length} posts"
      Post.find_many(post_ids).each_with_index { |post,i|
        puts "#{post['Title']} (#{i}/#{c})"
        post.tagify(skip_linking: true)      
      }    
    end
    200
  end
        
  get '/terms/:id/tagify' do 
    @term = begin; Term.find(params[:id]); rescue; not_found; end      
    @term.tagify   
    200
  end
    
  get'/terms/create_edges' do
    Term.all(filter: "AND({Sources} = '', {Sinks} = '')").each { |term|
      puts term['Name']
      term.create_edges
    }
    200
  end
    
  get '/terms/:id/create_edges' do
    @term = begin; Term.find(params[:id]); rescue; not_found; end      
    @term.create_edges
    200
  end  
  
  
  
    
  get '/organisations/:organisation', :cache => true do
    expires 1.hour.to_i
    @posts = Post.all(filter: "{Organisation} = '#{params[:organisation]}'", sort: { "Created at" => "desc" })                        
    erb :search
  end  
       
  get '/organisations/:id/tagify' do
    @organisation = begin; Organisation.find(params[:id]); rescue; not_found; end      
    @organisation.tagify   
    200
  end   


  
  
 get '/stats' do
    text = []
    hosts = []
    Post.all.each { |post|
      post_text = []
      json = JSON.parse(post['Iframely'])
      post_text << post['Title']
      if b = post['Body']          
        if !b.include?('use cookies') && !b.include?('use of cookies')        
          b = b.gsub(/Read [\d,]+ reviews from the world's largest community for readers. /,'')
          post_text << b 
        end
      end
      if json['meta']
        post_text << json['meta']['title'] if json['meta']['title']
        if d = json['meta']['description']
          d = d.gsub(/Read [\d,]+ reviews from the world's largest community for readers. /,'')
          post_text << d
        end
        post_text << json['meta']['category'] if json['meta']['category']
        post_text << json['meta']['keywords'].split(',').join(' ') if json['meta']['keywords']
      end
      text << post_text
      hosts << URI(post['Link']).host.gsub('www.','')                
    }
      
    stops = ["0o", "0s", "3a", "3b", "3d", "6b", "6o", "a", "A", "a1", "a2", "a3", "a4", "ab", "able", "about", "above", "abst", "ac", "accordance", "according", "accordingly", "across", "act", "actually", "ad", "added", "adj", "ae", "af", "affected", "affecting", "after", "afterwards", "ag", "again", "against", "ah", "ain", "aj", "al", "all", "allow", "allows", "almost", "alone", "along", "already", "also", "although", "always", "am", "among", "amongst", "amoungst", "amount", "an", "and", "announce", "another", "any", "anybody", "anyhow", "anymore", "anyone", "anyway", "anyways", "anywhere", "ao", "ap", "apart", "apparently", "appreciate", "approximately", "ar", "are", "aren", "arent", "arise", "around", "as", "aside", "ask", "asking", "at", "au", "auth", "av", "available", "aw", "away", "awfully", "ax", "ay", "az", "b", "B", "b1", "b2", "b3", "ba", "back", "bc", "bd", "be", "became", "been", "before", "beforehand", "beginnings", "behind", "below", "beside", "besides", "best", "between", "beyond", "bi", "bill", "biol", "bj", "bk", "bl", "bn", "both", "bottom", "bp", "br", "brief", "briefly", "bs", "bt", "bu", "but", "bx", "by", "c", "C", "c1", "c2", "c3", "ca", "call", "came", "can", "cannot", "cant", "cc", "cd", "ce", "certain", "certainly", "cf", "cg", "ch", "ci", "cit", "cj", "cl", "clearly", "cm", "cn", "co", "com", "come", "comes", "con", "concerning", "consequently", "consider", "considering", "could", "couldn", "couldnt", "course", "cp", "cq", "cr", "cry", "cs", "ct", "cu", "cv", "cx", "cy", "cz", "d", "D", "d2", "da", "date", "dc", "dd", "de", "definitely", "describe", "described", "despite", "detail", "df", "di", "did", "didn", "dj", "dk", "dl", "do", "does", "doesn", "doing", "don", "done", "down", "downwards", "dp", "dr", "ds", "dt", "du", "due", "during", "dx", "dy", "e", "E", "e2", "e3", "ea", "each", "ec", "ed", "edu", "ee", "ef", "eg", "ei", "eight", "eighty", "either", "ej", "el", "eleven", "else", "elsewhere", "em", "en", "end", "ending", "enough", "entirely", "eo", "ep", "eq", "er", "es", "especially", "est", "et", "et-al", "etc", "eu", "ev", "even", "ever", "every", "everybody", "everyone", "everything", "everywhere", "ex", "exactly", "example", "except", "ey", "f", "F", "f2", "fa", "far", "fc", "few", "ff", "fi", "fifteen", "fifth", "fify", "fill", "find", "fire", "five", "fix", "fj", "fl", "fn", "fo", "followed", "following", "follows", "for", "former", "formerly", "forth", "forty", "found", "four", "fr", "from", "front", "fs", "ft", "fu", "full", "further", "furthermore", "fy", "g", "G", "ga", "gave", "ge", "get", "gets", "getting", "gi", "give", "given", "gives", "giving", "gj", "gl", "go", "goes", "going", "gone", "got", "gotten", "gr", "greetings", "gs", "gy", "h", "H", "h2", "h3", "had", "hadn", "happens", "hardly", "has", "hasn", "hasnt", "have", "haven", "having", "he", "hed", "hello", "help", "hence", "here", "hereafter", "hereby", "herein", "heres", "hereupon", "hes", "hh", "hi", "hid", "hither", "hj", "ho", "hopefully", "how", "howbeit", "however", "hr", "hs", "http", "hu", "hundred", "hy", "i2", "i3", "i4", "i6", "i7", "i8", "ia", "ib", "ibid", "ic", "id", "ie", "if", "ig", "ignored", "ih", "ii", "ij", "il", "im", "immediately", "in", "inasmuch", "inc", "indeed", "index", "indicate", "indicated", "indicates", "information", "inner", "insofar", "instead", "interest", "into", "inward", "io", "ip", "iq", "ir", "is", "isn", "it", "itd", "its", "iv", "ix", "iy", "iz", "j", "J", "jj", "jr", "js", "jt", "ju", "just", "k", "K", "ke", "keep", "keeps", "kept", "kg", "kj", "km", "ko", "l", "L", "l2", "la", "largely", "last", "lately", "later", "latter", "latterly", "lb", "lc", "le", "least", "les", "less", "lest", "let", "lets", "lf", "like", "liked", "likely", "line", "little", "lj", "ll", "ln", "lo", "look", "looking", "looks", "los", "lr", "ls", "lt", "ltd", "m", "M", "m2", "ma", "made", "mainly", "make", "makes", "many", "may", "maybe", "me", "meantime", "meanwhile", "merely", "mg", "might", "mightn", "mill", "million", "mine", "miss", "ml", "mn", "mo", "more", "moreover", "most", "mostly", "move", "mr", "mrs", "ms", "mt", "mu", "much", "mug", "must", "mustn", "my", "n", "N", "n2", "na", "name", "namely", "nay", "nc", "nd", "ne", "near", "nearly", "necessarily", "neither", "nevertheless", "new", "next", "ng", "ni", "nine", "ninety", "nj", "nl", "nn", "no", "nobody", "non", "none", "nonetheless", "noone", "nor", "normally", "nos", "not", "noted", "novel", "now", "nowhere", "nr", "ns", "nt", "ny", "o", "O", "oa", "ob", "obtain", "obtained", "obviously", "oc", "od", "of", "off", "often", "og", "oh", "oi", "oj", "ok", "okay", "ol", "old", "om", "omitted", "on", "once", "one", "ones", "only", "onto", "oo", "op", "oq", "or", "ord", "os", "ot", "otherwise", "ou", "ought", "our", "out", "outside", "over", "overall", "ow", "owing", "own", "ox", "oz", "p", "P", "p1", "p2", "p3", "page", "pagecount", "pages", "par", "part", "particular", "particularly", "pas", "past", "pc", "pd", "pe", "per", "perhaps", "pf", "ph", "pi", "pj", "pk", "pl", "placed", "please", "plus", "pm", "pn", "po", "poorly", "pp", "pq", "pr", "predominantly", "presumably", "previously", "primarily", "probably", "promptly", "proud", "provides", "ps", "pt", "pu", "put", "py", "q", "Q", "qj", "qu", "que", "quickly", "quite", "qv", "r", "R", "r2", "ra", "ran", "rather", "rc", "rd", "re", "readily", "really", "reasonably", "recent", "recently", "ref", "refs", "regarding", "regardless", "regards", "related", "relatively", "research-articl", "respectively", "resulted", "resulting", "results", "rf", "rh", "ri", "right", "rj", "rl", "rm", "rn", "ro", "rq", "rr", "rs", "rt", "ru", "run", "rv", "ry", "s", "S", "s2", "sa", "said", "saw", "say", "saying", "says", "sc", "sd", "se", "sec", "second", "secondly", "section", "seem", "seemed", "seeming", "seems", "seen", "sent", "seven", "several", "sf", "shall", "shan", "shed", "shes", "show", "showed", "shown", "showns", "shows", "si", "side", "since", "sincere", "six", "sixty", "sj", "sl", "slightly", "sm", "sn", "so", "some", "somehow", "somethan", "sometime", "sometimes", "somewhat", "somewhere", "soon", "sorry", "sp", "specifically", "specified", "specify", "specifying", "sq", "sr", "ss", "st", "still", "stop", "strongly", "sub", "substantially", "successfully", "such", "sufficiently", "suggest", "sup", "sure", "sy", "sz", "t", "T", "t1", "t2", "t3", "take", "taken", "taking", "tb", "tc", "td", "te", "tell", "ten", "tends", "tf", "th", "than", "thank", "thanks", "thanx", "that", "thats", "the", "their", "theirs", "them", "themselves", "then", "thence", "there", "thereafter", "thereby", "thered", "therefore", "therein", "thereof", "therere", "theres", "thereto", "thereupon", "these", "they", "theyd", "theyre", "thickv", "thin", "think", "third", "this", "thorough", "thoroughly", "those", "thou", "though", "thoughh", "thousand", "three", "throug", "through", "throughout", "thru", "thus", "ti", "til", "tip", "tj", "tl", "tm", "tn", "to", "together", "too", "took", "top", "toward", "towards", "tp", "tq", "tr", "tried", "tries", "truly", "try", "trying", "ts", "tt", "tv", "twelve", "twenty", "twice", "two", "tx", "u", "U", "u201d", "ue", "ui", "uj", "uk", "um", "un", "under", "unfortunately", "unless", "unlike", "unlikely", "until", "unto", "uo", "up", "upon", "ups", "ur", "us", "used", "useful", "usefully", "usefulness", "using", "usually", "ut", "v", "V", "va", "various", "vd", "ve", "very", "via", "viz", "vj", "vo", "vol", "vols", "volumtype", "vq", "vs", "vt", "vu", "w", "W", "wa", "was", "wasn", "wasnt", "way", "we", "wed", "welcome", "well", "well-b", "went", "were", "weren", "werent", "what", "whatever", "whats", "when", "whence", "whenever", "where", "whereafter", "whereas", "whereby", "wherein", "wheres", "whereupon", "wherever", "whether", "which", "while", "whim", "whither", "who", "whod", "whoever", "whole", "whom", "whomever", "whos", "whose", "why", "wi", "widely", "with", "within", "without", "wo", "won", "wonder", "wont", "would", "wouldn", "wouldnt", "www", "x", "X", "x1", "x2", "x3", "xf", "xi", "xj", "xk", "xl", "xn", "xo", "xs", "xt", "xv", "xx", "y", "Y", "y2", "yes", "yet", "yj", "yl", "you", "youd", "your", "youre", "yours", "yr", "ys", "yt", "z", "Z", "zero", "zi", "zz"]
    terms = Term.all.map { |term| term['Name'].downcase }
    term_words = terms.map { |term| term.split(' ') }.flatten      
    text = text.flatten.join(' ').downcase
    r = /[\w'-]+/
    words = text.scan(/#{r}/) - stops - term_words
    phrases2 = text.scan(/#{r} #{r}/) - stops - terms            
    phrases2 += (text.split(' ')[1..-1].join(' ')+' ').scan(/#{r} #{r}/) - stops - terms
    phrases2 = phrases2.reject { |phrase| a, b = phrase.split(' '); stops.include?(a) && stops.include?(b) }
    @word_frequency = words.reduce(Hash.new(0)){|res,w| res[w.downcase]+=1;res}
    @phrase2_frequency = phrases2.reduce(Hash.new(0)){|res,w| res[w.downcase]+=1;res}
    @host_frequency = hosts.each_with_object(Hash.new(0)){|key,hash| hash[key] += 1}
    erb :stats
  end  
    
end