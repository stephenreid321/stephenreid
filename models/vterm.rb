class Vterm
  include Mongoid::Document
  include Mongoid::Timestamps

  field :term, type: String
  field :definition, type: String
  field :see_also, type: String
  field :weight, type: Integer

  def self.admin_fields
    {
      term: :text,
      definition: :text_area,
      see_also: :text,
      weight: :number
    }
  end

  has_many :vedges_as_source, class_name: 'Vedge', inverse_of: :source, dependent: :destroy
  has_many :vedges_as_sink, class_name: 'Vedge', inverse_of: :sink, dependent: :destroy

  validates_uniqueness_of :term

  def videos
    ids = []
    ids += Video.where(text: /\b#{term}\b/i).pluck(:id)
    ids += Video.where(text: /\b#{term.pluralize}\b/i).pluck(:id) if term.pluralize != term
    Video.where(:id.in => ids)
  end

  before_validation do
    set_weight if weight.blank?
  end

  def set_weight
    self.weight = videos.count
  end

  after_save do
    set_definition! if definition.blank?
    set_see_also! if see_also.blank?
  end
  def set_definition!
    n = 1
    context = Vterm.hints[term] || 'as if written by Daniel Schmachtenberger'
    openapi_response = OPENAI.post('completions') do |req|
      req.body = { model: 'text-davinci-003', max_tokens: 1024, n: n, prompt:
        "Provide a postgraduate-level definition of the term '#{term}', #{context}.

        The definition should be 1 paragraph, maximum 150 words." }.to_json
    end
    self.definition = JSON.parse(openapi_response.body)['choices'].first['text']
    tidy_definition
    save
  end
  handle_asynchronously :set_definition!

  def set_see_also!
    openapi_response = OPENAI.post('completions') do |req|
      req.body = { model: 'text-davinci-003', max_tokens: 1024, prompt:
        "Select the 5 terms from the list below that are most relevant to the term '#{term}'.

        #{(Vterm.interesting - [term]).join(', ')}.

        Return the result as a comma-separated list, e.g. 'term1, term2, term3, term4, term5'.

        " }.to_json
    end

    see_also = JSON.parse(openapi_response.body)['choices'].first['text'].strip
    see_also = see_also.split(', ').map { |term| term.downcase }.select { |term| Vterm.interesting.include?(term) && term != self.term }.join(', ')
    self.see_also = see_also
    save
  end
  handle_asynchronously :set_see_also!

  def see_also_ids
    see_also ? Vterm.where(:term.in => see_also.split(', ')).pluck(:id) : []
  end

  def self.dashed_terms_to_undash
    %w[
      multi-polar
      non-linear
      hyper-normal
    ]
  end

  def self.spaced_terms_to_unspace
    [
      'meta crisis',
      'super organism',
      'sense making',
      'hyper normal'
    ]
  end

  def self.spaced_terms_to_dash
    [
      'self terminating'
    ]
  end

  def self.terms_to_tidy
    dashed_terms_to_undash + spaced_terms_to_unspace + spaced_terms_to_dash
  end

  def tidy_definition
    Vterm.dashed_terms_to_undash.each do |term|
      self.definition = definition.gsub(/#{term}/i, term.gsub('-', ''))
    end
    Vterm.spaced_terms_to_unspace.each do |term|
      self.definition = definition.gsub(/#{term}/i, term.gsub(' ', ''))
    end
    Vterm.spaced_terms_to_dash.each do |term|
      self.definition = definition.gsub(/#{term}/i, term.gsub(' ', '-'))
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
      catastrophe weapon
      catastrophic risk
      civilizational collapse
      climate change
      collective action
      collective intelligence
      complexity science
      confirmation bias
      conflict theory
      coordination failure
      critical infrastructure
      decision making
      dunbar number
      dystopia
      embedded growth obligation
      emergent property
      epistemic commons
      existential risk
      existential threat
      exponential growth
      exponential tech
      fourth estate
      game b
      game theory
      generator function
      global governance
      human nature
      hypernormal stimuli
      liquid democracy
      materials economy
      metacrisis
      mistake theory
      multipolar trap
      mutually assured destruction
      narrative warfare
      nation state
      network dynamics
      network theory
      nonlinear dynamics
      nuclear weapon
      open society
      open source
      paperclip maximizer
      permaculture
      perverse incentive
      planetary boundary
      plausible deniability
      race to the bottom
      regenerative agriculture
      rivalrous dynamics
      self-terminating
      sensemaking
      social media
      social structure
      social system
      social tech
      superorganism
      superstructure
      supply chain
      systems thinking
      third attractor
      web3
  ).split("\n").reject { |x| x.blank? }.map { |x| x.strip }
    # complex system
  end

  def self.hints
    {
      'self-terminating' => 'as if written by Daniel Schmachtenberger, in the context of failed civilizations',
      'embedded growth obligation' => 'as if written by Daniel Schmachtenberger, in the context of failed civilizations'
    }
  end

  def self.plurals
    interesting.map { |term| term.pluralize }
  end

  def self.edgeless
    Vterm.where(:id.nin => Vedge.pluck(:source_id) + Vedge.pluck(:sink_id))
  end

  def generate_edges
    source = self
    (Vterm.all - [source]).each { |sink| Vedge.find_or_create(source, sink) }
  end

  def self.generate_edges
    Vterm.edgeless.each { |source| source.generate_edges }
  end

  def linked_definition
    d = definition.strip + "\n\nSee also: #{see_also}"
    d.gsub!(/‘(#{term.pluralize})’/i, %(\\0))
    d.gsub!(/‘(#{term})’/i, %(\\0)) if term.pluralize != term
    d.gsub!(/“(#{term.pluralize})”/i, %(\\0))
    d.gsub!(/“(#{term})”/i, %(\\0)) if term.pluralize != term
    d.gsub!(/\b(#{term.pluralize})\b/i, %(<mark class="text-white">\\0</mark>))
    d.gsub!(/\b(#{term})\b/i, %(<mark class="text-white">\\0</mark>)) if term.pluralize != term
    (['metacrisis'] + ((Vterm.plurals + Vterm.interesting).uniq - ['metacrisis']) - [term, term.pluralize]).each do |t|
      d.gsub!(/\b(#{t})\b/i, %(<a href="/metacrisis/terms/#{t}">\\0</a>))
    end
    d
  end
end
