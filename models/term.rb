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
  
  def create_edges
    source = self
    puts "wiping edges connected to #{source['Name']}"
    TermLink.all({filter: "OR({Source} = '#{source['Name']}', {Sink}  = '#{source['Name']}')"}).each { |term_link|
      term_link.posts = []
      term_link.save
    }
    
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
        puts "adding posts for #{source['Name']} <-> #{sink['Name']}"
        term_link.posts = Post.all(filter: "AND(
        FIND(', #{ source['Name']},', {Terms joined}) > 0,
        FIND(', #{ sink['Name']},', {Terms joined}) > 0
        )")
        term_link.save
      end
    }
  end
  
end