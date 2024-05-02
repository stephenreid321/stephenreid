class Term < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Terms'

  belongs_to :organisation, class: 'Organisation', column: 'Organisation'

  has_many :posts, class: 'Post', column: 'Posts'

  def tagify
    term = self
    posts = Post.all(filter: "
        OR(
          FIND(LOWER('#{term['Name']}'), LOWER({Title})) > 0,
          FIND(LOWER('#{term['Name']}'), LOWER({Body})) > 0,
          FIND(LOWER('#{term['Name']}'), LOWER({Iframely})) > 0
        )
      ", sort: { 'Created at' => 'desc' })
    posts.each do |post|
      puts post['Title']
      post.tagify(skip_linking: true)
    end
  end

  def self.create_edges
    checked = []
    Term.all.each_with_index do |source, i|
      Term.all.each_with_index do |sink, j|
        next unless source.id != sink.id && !checked.include?([source.id, sink.id]) && !checked.include?([sink.id, source.id])

        puts "#{source['Name']} <-> #{sink['Name']} (#{i},#{j})"
        checked << [source.id, sink.id]

        posts = TermLink.get_posts(source['Name'], sink['Name'])

        next if posts.empty?

        puts "found #{posts.length} posts"

        term_link = TermLink.find_or_create(source, sink)

        post_ids = posts.map(&:id)

        if (missing = post_ids - (term_link['Posts'] || []))
          missing.each do |post_id|
            puts "missing: #{post_id}"
            term_link['Posts'] = (term_link['Posts'] + [post_id])
          end
        end
        if (superfluous = (term_link['Posts'] || []) - post_ids)
          superfluous.each do |post_id|
            puts "superfluous: #{post_id}"
            term_link['Posts'] = (term_link['Posts'] - [post_id])
          end
        end
        term_link.save
      end
    end
  end

  def create_edges
    source = self
    puts "collecting sinks for #{source['Name']}"
    sink_ids = []
    source.posts.each do |post|
      sink_ids += post['Terms']
    end
    sink_ids = sink_ids.uniq - [source.id]
    puts "sinks: #{sink_ids.count}"

    sink_ids.each do |sink_id|
      sink = Term.find(sink_id)
      term_link = TermLink.find_or_create(source, sink)
      puts "#{source['Name']} <-> #{sink['Name']}"
      term_link.posts = term_link.get_posts
      term_link.save
    end
  end

  def get_posts(since: nil)
    term = self
    Term.get_posts(term['Name'], since: since)
  end

  def self.get_posts(name, since: nil)
    filter = "FIND(', #{name},', {Terms joined}) > 0"
    filter = "AND(#{filter}, {Created at} > '#{since.to_s(:db)}')" if since
    Post.all(filter: filter)
  end
end
