class BlogPost
  include Mongoid::Document
  include Mongoid::Timestamps

  field :title, type: String
  field :slug, type: String
  field :body, type: String
  field :image_word, type: String
  field :image_url, type: String
  field :version, type: String

  validates_presence_of :title
  validates_uniqueness_of :slug

  def self.admin_fields
    {
      title: :text,
      slug: :text,
      image_word: :text,
      body: :text_area,
      image_url: :url,
      version: :text
    }
  end

  def self.version
    'gpt-4'
  end

  def previous
    BlogPost.where(:id.lt => id).order_by(:id.desc).first
  end

  def next
    BlogPost.where(:id.gt => id).order_by(:id.asc).first
  end

  def url
    "/ai/#{slug}"
  end

  def set_body!
    openai_response = OPENAI.post('chat/completions') do |req|
      req.body = { model: BlogPost.version, messages: [{ role: 'user', content: prompt.join("\n\n") }] }.to_json
    end
    content = JSON.parse(openai_response.body)['choices'][0]['message']['content']
    self.body = content.split("\n")[1..-1].join("\n")
    save
  end
  handle_asynchronously :set_body!

  def image_prompt
    %(Suggest a common, single word that, as an image, would best represent a blog post with the title '#{title}'. Return ONLY the word, with no text before or after.)
  end

  def set_image_word!
    openai_response = OPENAI.post('chat/completions') do |req|
      req.body = { model: 'gpt-3.5-turbo', messages: [{ role: 'user', content: image_prompt }] }.to_json
    end
    content = JSON.parse(openai_response.body)['choices'][0]['message']['content']
    self.image_word = content.downcase.match(/\w+/)[0]
    set_image
    save
  end
  handle_asynchronously :set_image_word!

  def set_image
    self.image_url = Faraday.get("https://source.unsplash.com/random/800x600?#{image_word}").headers[:location]
  end

  def prompt
    [
      %(
Write a 700-word blog post in the first person, as if written by the person below, on the topic of '#{title}'.

- Write the title of the blog post on the first line.
- Start each section with a heading with two hashes like this: ## Heading
- There should be a maximum of 5 sections.
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
#{Book.all(sort: { 'ID' => 'asc' }).first(50).map { |b| "[#{b['Title']}](https://www.goodreads.com#{b['URL']}) by #{b['Author']}" }.join("\n\n")}),
      %(## Content I've shared recently
#{Post.all(filter: "IS_AFTER({Created at}, '#{1.month.ago.to_s(:db)}')", sort: { 'Created at' => 'desc' }).first(10).map { |post| "[#{post['Title']}](#{post['Link']})\n#{post['Body']}" }.join("\n\n")})
      # %(## Speaking engagements
      # #{SpeakingEngagement.all(filter: '{Hidden} = 0', sort: { 'Date' => 'desc' }).map { |speaking_engagement| "#{[speaking_engagement['Date'], speaking_engagement['Location'], speaking_engagement['Organisation Name']].compact.join(', ')}: #{speaking_engagement['Name']}" }.join("\n\n")}),
      # %(## Blog posts I've written
      #   #{Dir['app/jekyll_blog/_posts/*.md'].sort.reverse.map do |f|
      #       content = File.read(f)
      #       yaml = YAML.load(content)
      #       "### #{yaml['title']}\n#{yaml['excerpt']}"
      #     end.join("\n\n")})
    ]
  end

  before_validation do
    self.title = title.titleize if title && title.downcase == title
    self.slug = title.parameterize if !slug && title
    self.version = BlogPost.version
  end

  after_create do
    Padrino.env == :development ? set_image_word_without_delay! : set_image_word!
    Padrino.env == :development ? set_body_without_delay! : set_body!
    # send an email notification
    blog_post = self
    mail = Mail.new do
      from 'notifications@stephenreid.net'
      to 'stephen@stephenreid.net'
      subject "New blog post: #{blog_post.title}"
      body "https://stephenreid.net#{blog_post.url}"
    end
    mail.deliver if Padrino.env == :production
  end
end
