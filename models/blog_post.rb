class BlogPost
  include Mongoid::Document
  include Mongoid::Timestamps

  field :title, type: String
  field :slug, type: String
  field :body, type: String
  field :image_word, type: String
  field :image_url, type: String
  field :version, type: String
  field :public, type: Boolean

  validates_presence_of :title
  validates_uniqueness_of :slug

  attr_accessor :skip_notification

  def self.admin_fields
    {
      title: :text,
      public: :check_box,
      slug: :text,
      image_word: :text,
      body: :text_area,
      image_url: :url,
      version: :text
    }
  end

  def self.version
    'gpt-4o'
  end

  def previous
    BlogPost.where(:public => true, :id.lt => id).order_by(:id.desc).first
  end

  def next
    BlogPost.where(:public => true, :id.gt => id).order_by(:id.asc).first
  end

  def url
    "/ai/#{slug}"
  end

  def set_body!
    openai_response = OPENAI.post('chat/completions') do |req|
      req.body = { model: version, messages: [{ role: 'user', content: prompt.join("\n\n") }] }.to_json
    end
    content = JSON.parse(openai_response.body)['choices'][0]['message']['content']
    self.body = content.split("\n")[1..].join("\n")
    save
  end
  handle_asynchronously :set_body!

  def image_prompt
    %(Suggest a common, single word that, as an image, would best represent a blog post with the title '#{title}'. Return ONLY the word, with no text before or after.)
  end

  def set_image_word!
    openai_response = OPENAI.post('chat/completions') do |req|
      req.body = { model: version, messages: [{ role: 'user', content: image_prompt }] }.to_json
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
- The post should synthesise and integrate the author's interests and expertise.
- Do not include biographical information.
- Do not include statements like 'As a physicist' or 'As a coach'.
- Reference at least one book the author has read.
- Assume the audience is highly intelligent.
- Make sure the post has a proper conclusion.
---)
    ] + Prompt.prompt
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
    mail.deliver if Padrino.env == :production && !skip_notification
  end

  def self.confirm(title, email)
    mail = Mail.new do
      from 'Stephen Reid <stephen@stephenreid.net>'
      to email
      subject title
      body "Click here to generate your post: https://stephenreid.net/ai/generate/#{BlogPost.encrypt(title)}"
    end
    mail.deliver if Padrino.env == :production
  end

  def self.encrypt(text)
    cipher = OpenSSL::Cipher.new('AES-256-ECB')
    cipher.encrypt
    cipher.key = Digest::MD5.hexdigest(ENV['ENCRYPTION_KEY'])
    encrypted = cipher.update(text) + cipher.final
    Base64.encode64(encrypted).gsub("\n", '').gsub('/', '_').gsub('+', '-')
  end

  def self.decrypt(ciphertext)
    cipher = OpenSSL::Cipher.new('AES-256-ECB')
    cipher.decrypt
    cipher.key = Digest::MD5.hexdigest(ENV['ENCRYPTION_KEY'])
    decoded = Base64.decode64(ciphertext.gsub('_', '/').gsub('-', '+'))
    decrypted = cipher.update(decoded) + cipher.final
    decrypted.force_encoding('utf-8')
  end
end
