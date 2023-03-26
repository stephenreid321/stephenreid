class BlogPost
  include Mongoid::Document
  include Mongoid::Timestamps

  field :title, type: String
  field :slug, type: String
  field :body, type: String
  field :image_url, type: String

  validates_uniqueness_of :slug

  def self.admin_fields
    {
      title: :text,
      slug: :text,
      body: :text_area,
      image_url: :url
    }
  end

  def previous
    BlogPost.where(:id.lt => id).order_by(:id.desc).first
  end

  def next
    BlogPost.where(:id.gt => id).order_by(:id.asc).first
  end

  def url
    "/blog/ai/#{slug}"
  end

  def self.generate
    messages = []
    messages << { role: 'user', content: prompt.join("\n ") }
    openapi_response = OPENAI.post('chat/completions') do |req|
      req.body = { model: 'gpt-3.5-turbo', messages: messages }.to_json
    end
    content = JSON.parse(openapi_response.body)['choices'][0]['message']['content']
    BlogPost.create(
      title: content.split("\n").first.gsub('#', ''),
      body: content.split("\n")[1..-1].join("\n")
    )
  end

  def self.prompt
    [
      %(
Write a 700-word blog post in the first person, as if written by the person below, on a topic they would be interested in.

- Write the title of the blog post on the first line.
- Start each section with a heading with two hashtags like this: ## Heading
- There should be maximum of 5 sections.
- Most sections should have at least two paragraphs.
- The post should integrate the author's interests and expertise, but not include biographical information.
- Reference at least one book the author has read.
- Write for a postgraduate-level audience.
- Make sure the post has a proper conclusion.
---),
      %(Hi! I'm Stephen.
I live in Totnes, Devon, UK, half an hour from Dartmoor, and half an hour from the South Devon coast.
## Short bio in the third person
#{open("#{Padrino.root}/app/markdown/bio.md").read.force_encoding('utf-8')}),
      %(## Training and teachers
#{open("#{Padrino.root}/app/markdown/training.md").read.force_encoding('utf-8')}),
      %(## Books I've read
#{Book.all(sort: { 'ID' => 'desc' }).first(20).map { |b| "#{b['Title']} by #{b['Author']}" }.join("\n\n")})
    ]
    # %(## Speaking engagements
    # {SpeakingEngagement.all(filter: '{Hidden} = 0', sort: { 'Date' => 'desc' }).map { |speaking_engagement| "#{[speaking_engagement['Date'], speaking_engagement['Location'], speaking_engagement['Organisation Name']].compact.join(', ')}: #{speaking_engagement['Name']}" }.join("\n\n")}),
  end

  before_validation do
    self.slug = title.parameterize if title
    openai_response = OPENAI.post('images/generations') do |req|
      req.body = { prompt: "Hilma AF Klint: #{title}", size: '512x512' }.to_json
    end
    self.image_url = JSON.parse(openai_response.body)['data'][0]['url']
  end
end
