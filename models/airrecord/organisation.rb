class Organisation < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Organisations'

  belongs_to :interest, class: 'Interest', column: 'Interest'

  has_many :affiliations, class: 'Affiliation', column: 'Affiliations'
  has_many :qualifications, class: 'Qualification', column: 'Qualifications'
  has_many :speaking_engagements, class: 'SpeakingEngagement', column: 'Speaking engagements'
  has_many :terms, class: 'Term', column: 'Terms'
  has_many :posts, class: 'Post', column: 'Posts'

  def self.categories
    {
      'Key places and processes' => 'key',
      'Plans for the future' => 'future',
      'Academic study' => 'academic',
      "Organisations I've worked with" => 'work',
      "Communities I've spent time at" => 'communities',
      'Landscapes that have inspired me' => 'landscapes',
      'Favourite shops and restaurants' => 'shops'
    }
  end

  def tagify
    organisation = self
    posts = Post.all(filter: "FIND('#{organisation['Domain']}', {Link}) > 0", sort: { 'Created at' => 'desc' })
    posts.each do |post|
      puts post['Title']
      post.tagify
    end
  end
end
