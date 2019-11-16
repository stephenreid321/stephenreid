class Term < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = "Terms"    
    
  belongs_to :organisation, :class => 'Organisation', :column => 'Organisation'    
  
  has_many :posts, :class => 'Post', :column => 'Posts'

  def tagify
    term = self
    posts = Post.all(filter: "
        OR(
          FIND(LOWER('#{term['Name']}'), LOWER({Title})) > 0,
          FIND(LOWER('#{term['Name']}'), LOWER({Body})) > 0,
          FIND(LOWER('#{term['Name']}'), LOWER({Iframely})) > 0
        )
      ", sort: { "Created at" => "desc" })
    posts.each { |post| puts post['Title']; post.tagify }
  end
  
  def self.create_edges
    checked = []
    Term.all.each_with_index { |source,i|
      Term.all.each_with_index { |sink,j|
        if source.id != sink.id && !checked.include?([source.id,sink.id]) && !checked.include?([sink.id,source.id])
                              
          puts "#{source['Name']} <-> #{sink['Name']} (#{i},#{j})"
          checked << [source.id, sink.id]
          
          posts = Post.all(filter: "AND(
            FIND(', #{ source['Name']},', {Terms joined}) > 0,
            FIND(', #{ sink['Name']},', {Terms joined}) > 0
          )")
          
          if posts.length > 0
            puts "found #{posts.length} posts"
                      
            if !(term_link = TermLink.all(filter: "AND({Source} = '#{source['Name']}', {Sink}  = '#{sink['Name']}')").first) && !(term_link = TermLink.all({filter: "AND({Source} = '#{sink['Name']}', {Sink}  = '#{source['Name']}')"}).first)
              term_link = TermLink.create("Source" => [source.id], "Sink" => [sink.id])
            end                                
          
            post_ids = posts.map(&:id)
          
            if missing = post_ids - (term_link['Posts'] || [])
              missing.each { |post_id|
                puts "missing: #{post_id}"
                term_link['Posts'] = (term_link['Posts'] + [post_id])
              }
            end    
            if superfluous = (term_link['Posts'] || []) - post_ids
              superfluous.each { |post_id|
                puts "superfluous: #{post_id}"
                term_link['Posts'] = (term_link['Posts'] - [post_id])
              }
            end
            term_link.save
          end
        end
      }
    }    
  end
  
  def create_edges
    source = self    
    puts "collecting sinks for #{source['Name']}"
    sink_ids = []
    source.posts.each { |post|
      sink_ids += post['Terms']
    }
    sink_ids = sink_ids.uniq
    puts "found #{sink_ids.count} unique sink IDs: #{sink_ids}"
    
    sink_ids.each { |sink_id|
      if source.id != sink_id
        sink = Term.find(sink_id)
        if !(term_link = TermLink.all(filter: "AND({Source} = '#{source['Name']}', {Sink}  = '#{sink['Name']}')").first) && !(term_link = TermLink.all({filter: "AND({Source} = '#{sink['Name']}', {Sink}  = '#{source['Name']}')"}).first)
          term_link = TermLink.create("Source" => [source.id], "Sink" => [sink.id])
        end
        puts "setting posts for #{source['Name']} <-> #{sink['Name']}"
        term_link.posts = term_link.get_posts
        term_link.save
      end
    }
  end
  
end