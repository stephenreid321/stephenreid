class Post < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Posts"        
  
  has_many :terms, :class => 'Term', :column => 'Terms'
  
  belongs_to :organisation, :class => 'Organisation', :column => 'Organisation'    
  
  def tagify
    post = self
    json = JSON.parse(post['Iframely'])
    twitter = post['Title']
    facebook = post['Title']            
    replacements, additions = [], []
      
    Term.all(sort: { "Priority" => "desc" }).each { |term|                  
      i = term['Case sensitive'] ? false : true
      t = term['Name']
      if post['Title'].match(i ? /\b#{t}\b/i : /\b#{t}\b/)
        replacements << term
      end        
      if [post['Body']].any? { |x| x && x.match(i ? /\b#{t}\b/i : /\b#{t}\b/) }
        additions << term        
      end
      if json['meta'] && [json['meta']['title'], json['meta']['description'], json['meta']['keywords']].any? { |x| x && x.match(i ? /\b#{t}\b/i : /\b#{t}\b/) }
        additions << term
      end
    }
      
    replacements.each { |term|
      i = term['Case sensitive'] ? false : true
      t = term['Name']
      hashtag = t.include?(' ') ? t.gsub(' ','_').camelize : t
      if term['Organisation']
        twitter = twitter.gsub(i ? /\b#{t}\b/i : /\b#{t}\b/, "@#{term.organisation['Twitter username']}")
        # facebook = facebook.gsub(i ? /#{t}/i : /#{t}/, "@[#{term.organisation['Facebook page username']}]")             
      else
        twitter = twitter.gsub(i ? /\b#{t}\b/i : /\b#{t}\b/, "##{hashtag}")
        facebook = facebook.gsub(i ? /\b#{t}\b/i : /\b#{t}\b/, "##{hashtag}")
      end
    }
      
    twitter_add, facebook_add = [], []
    (additions - replacements).each { |term|
      t = term['Name']
      hashtag = t.include?(' ') ? t.gsub(' ','_').camelize : t
      if term['Organisation']
        twitter_add << "@#{term.organisation['Twitter username']}"
        # facebook_add << "@[#{term.organisation['Facebook page username']}]"
      else
        twitter_add << "##{hashtag}"
        facebook_add << "##{hashtag}"
      end        
    }
    
    if organisation = Organisation.all(filter: "{Domain} = '#{URI(post['Link']).host.gsub('www.','')}'").first
      post.organisation = organisation
      twitter_add << "@#{organisation['Twitter username']}"
      # facebook_add << "@[#{organisation['Facebook page username']}]"
    end
    
    twitter_add.uniq.each { |x| twitter = "#{twitter} #{x}" }
    facebook_add.uniq.each { |x| facebook = "#{facebook} #{x}" }
    
    post.terms = (additions + replacements).uniq            
    post['Twitter text'] = twitter
    post['Facebook text'] = facebook
    post.save             
  end
  
end