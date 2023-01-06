class Vterm
  include Mongoid::Document
  include Mongoid::Timestamps

  field :term, type: String
  field :definition, type: String

  def self.admin_fields
    {
      term: :text,
      definition: :text_area
    }
  end

  validates_uniqueness_of :term

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
    save
  end
  handle_asynchronously :set_definition!

  def linked_definition
    d = definition
    d.gsub!("‘#{term}’", term)
    d.gsub!(term.pluralize.humanize, %(<mark class="text-white">#{term.pluralize.humanize}</mark>))
    if term.pluralize != term
      d.gsub!(term.humanize, %(<mark class="text-white">#{term.humanize}</mark>))
      d.gsub!(term, %(<mark class="text-white">#{term}</mark>))
    end
    ((Vterm.plurals + Vterm.interesting).uniq - [term]).each do |t|
      d.gsub!(/\b#{t}\b/, %(<a href="/metacrisis/terms/#{t}">#{t}</a>))
    end
    d
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
      infrastructure
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
end
