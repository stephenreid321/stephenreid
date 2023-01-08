class Vterm
  include Mongoid::Document
  include Mongoid::Timestamps

  field :term, type: String
  field :definition, type: String
  field :weight, type: Integer

  def self.admin_fields
    {
      term: :text,
      definition: :text_area,
      weight: :number
    }
  end

  has_many :vedges_as_source, class_name: 'Vedge', inverse_of: :source, dependent: :destroy
  has_many :vedges_as_sink, class_name: 'Vedge', inverse_of: :sink, dependent: :destroy

  validates_uniqueness_of :term

  before_validation do
    set_weight if weight.blank?
  end

  def videos
    ids = []
    ids += Video.where(text: /\b#{term}\b/i).pluck(:id)
    ids += Video.where(text: /\b#{term.pluralize}\b/i).pluck(:id) if term.pluralize != term
    Video.where(:id.in => ids)
  end

  def set_weight
    self.weight = videos.count
  end

  after_save do
    set_definition! if definition.blank?
  end
  def set_definition!
    openapi_response = OPENAI.post('completions') do |req|
      req.body = { model: 'text-davinci-003', max_tokens: 1024, prompt:
        "Consider this list of related terms: #{Vterm.interesting.join(', ')}.

        Provide a postgraduate-level definition of the term '#{term}', as if written by Daniel Schmachtenberger.

        The definition should be a minimum of 300 words and refer to at least 3 other concepts in the list." }.to_json
    end
    self.definition = JSON.parse(openapi_response.body)['choices'].first['text']
    tidy_definition
    save
  end
  handle_asynchronously :set_definition!

  def tidy_definition
    %w[
      multi-polar
      non-linear
    ].each do |term|
      self.definition = definition.gsub(term, term.gsub('-', ''))
    end
    ['sense making'].each do |term|
      self.definition = definition.gsub(term, term.gsub(' ', ''))
    end
  end

  def self.populate
    interesting.each { |term| Vterm.create(term: term) }
  end

  def self.interesting
    %(
      apex predator
      arms race
      artificial intelligence
      biosecurity
      blockchain
      bretton woods
      catastrophic risk
      catastrophic threat
      civilizational collapse
      climate change
      collective action
      collective intelligence
      complexity science
      coordination failure
      critical infrastructure
      decision making
      dunbar number
      dystopia
      epistemic commons
      existential risk
      existential threat
      exponential growth
      exponential tech
      fourth estate
      game b
      game theory
      global governance
      human nature
      materials economy
      multipolar trap
      mutually assured destruction
      nation state
      network dynamics
      network theory
      nonlinear dynamics
      nonlinear system
      nuclear weapon
      open society
      open source
      permaculture
      perverse incentive
      planetary boundary
      race to the bottom
      regenerative agriculture
      regenerative economics
      sensemaking
      social media
      social structure
      social system
      social tech
      superstructure
      supply chain
      systems thinking
      third attractor
      web3
  ).split("\n").reject { |x| x.blank? }.map { |x| x.strip }
  end

  def self.plurals
    interesting.map { |term| term.pluralize }
  end

  def linked_definition
    d = definition
    d.gsub!(/‘(#{term.pluralize})’/i, %(\\0))
    d.gsub!(/‘(#{term})’/i, %(\\0)) if term.pluralize != term
    d.gsub!(/\b(#{term.pluralize})\b/i, %(<mark class="text-white">\\0</mark>))
    d.gsub!(/\b(#{term})\b/i, %(<mark class="text-white">\\0</mark>)) if term.pluralize != term
    ((Vterm.plurals + Vterm.interesting).uniq - [term, term.pluralize]).each do |t|
      d.gsub!(/\b(#{t})\b/i, %(<a href="/metacrisis/terms/#{t}">\\0</a>))
    end
    d
  end
end
