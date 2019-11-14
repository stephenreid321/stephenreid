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
    TermLink.all({filter: "OR({Source} = '#{source['Name']}', {Sink}  = '#{source['Name']}')"}).each { |term_link|
      term_link.posts = []
      term_link.save
    }
    source.posts.each { |post|
      post.terms.each { |sink|
        if source.id != sink.id
          if !(term_link = TermLink.all({filter: "AND({Source} = '#{source['Name']}', {Sink}  = '#{sink['Name']}')"}).first) && !(term_link = TermLink.all({filter: "AND({Source} = '#{sink['Name']}', {Sink}  = '#{source['Name']}')"}).first)
            term_link = TermLink.create("Source" => [source.id], "Sink" => [sink.id])
          end
          term_link.posts = term_link.posts + [post]
          term_link.posts = term_link.posts.uniq
          term_link.save
        end
      }
    }
  end
  
end