class TermLink < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Term Links'

  belongs_to :source, class: 'Term', column: 'Source'
  belongs_to :sink, class: 'Term', column: 'Sink'

  has_many :posts, class: 'Post', column: 'Posts'

  def get_posts
    term_link = self
    TermLink.get_posts(term_link['Source name'], term_link['Sink name'])
  end

  def self.get_posts(source_name, sink_name)
    Post.all(filter: "AND(
        FIND(', #{source_name},', {Terms joined}) > 0,
        FIND(', #{sink_name},', {Terms joined}) > 0
      )")
  end

  def self.find_or_create(source, sink)
    if !(term_link = TermLink.all(filter: "AND({Source} = '#{source['Name']}', {Sink}  = '#{sink['Name']}')").first) && !(term_link = TermLink.all(filter: "AND({Source} = '#{sink['Name']}', {Sink}  = '#{source['Name']}')").first)
      term_link = TermLink.create('Source' => [source.id], 'Sink' => [sink.id])
    end
    term_link
  end
end
