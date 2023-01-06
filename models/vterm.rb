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

  before_validation do
    set_definition if definition.blank?
  end

  validates_uniqueness_of :term

  def set_definition
    openapi_response = OPENAI.post('completions') do |req|
      req.body = { model: 'text-davinci-003', max_tokens: 1024, prompt:
        "Consider this list of related terms: #{Vterm.interesting.join(', ')}.

        Provide a postgraduate-level definition of the term '#{term}', as if written by Daniel Schmachtenberger.

        The definition should be a minimum of 300 words and refer to at least 3 other concepts in the list." }.to_json
    end
    self.definition = JSON.parse(openapi_response.body)['choices'].first['text']
  end

  def linked_definition
    d = definition
    d.gsub!("‘#{term}’", term)
    d.gsub!(term, %(<mark class="text-white">#{term}</mark>))
    (Vterm.interesting - [term]).each do |t|
      d.gsub!(t, %(<a href="/metacrisis/terms/#{t}">#{t}</a>))
    end
    d
  end

  def self.populate
    interesting.each { |term| Vterm.create(term: term) }
    plurals.each { |term| Vterm.create(term: term) }
  end

  def self.interesting
    %(
    arms race
    race to the bottom

    multipolar trap

    materials economy

    collective intelligence
    game theory
    game theoretic
    network theory

    catastrophic risk
    catastrophic threat
    existential risk
    existential threat

    nation state

    apex predator
    dunbar number
    exponential growth
    collective action

    nuclear weapon
    planetary boundary

    supply chain

    civilizational collapse
    climate change

    sensemaking
    sense making
    game b

    artificial intelligence
    blockchain
    web3
    social media

    complexity science
    systems thinking

    global governance
    fourth estate
    social tech
    mutually assured destruction
    open source
    perverse incentive
    human nature
    epistemic commons
    network dynamics
    open society
    social system
    bretton woods

    nonlinear system
    nonlinear dynamics

    decision making

    biosecurity
    critical infrastructure

    regenerative agriculture
    regenerative economics
    permaculture

    coordination failure

    superstructure
    social structure
    infrastructure

    third attractor
    dystopia

    exponential tech
  ).split("\n").reject { |x| x.blank? }.map { |x| x.strip }
  end

  def self.plurals
    interesting.map { |term| term.pluralize }
  end
end
