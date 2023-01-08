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
  end
  def set_definition!
    n = 1
    openapi_response = OPENAI.post('completions') do |req|
      req.body = { model: 'text-davinci-003', max_tokens: 1024, n: n, prompt:
        "Provide a postgraduate-level definition of the term '#{term}', as if written by Daniel Schmachtenberger.

        The definition should be 1 paragraph, maximum 150 words." }.to_json
    end

    #  Refer to a maximum of 3 terms from this list: #{Vterm.interesting.join(', ')}.

    openapi_response_b = OPENAI.post('completions') do |req|
      req.body = { model: 'text-davinci-003', max_tokens: 1024, prompt:
        "Select the 5 terms from the list below that are most relevant to the term '#{term}'.

        #{(Vterm.interesting - [term]).join(', ')}.

        Return the result as a comma-separated list, e.g. 'term1, term2, term3, term4, term5'.

        " }.to_json
    end

    see_also = JSON.parse(openapi_response_b.body)['choices'].first['text'].strip
    see_also = see_also.split(', ').map { |term| term.downcase }.select { |term| Vterm.interesting.include?(term) && term != self.term }.join(', ')
    self.definition = JSON.parse(openapi_response.body)['choices'].first['text'] + "\n\nSee also: #{see_also}"

    # openapi_response_a = OPENAI.post('completions') do |req|
    #   req.body = { model: 'text-davinci-003', max_tokens: 1024, prompt:
    #     "Consider these #{n} definitions of the term '#{term}':

    #     #{(1..n).map { |i| "#{i}. #{JSON.parse(openapi_response.body)['choices'][i - 1]['text']}" }.join("\n\n")}

    #     Output the best definition verbatim." }.to_json
    # end

    # self.definition = JSON.parse(openapi_response_a.body)['choices'].first['text']

    tidy_definition
    save
  end
  handle_asynchronously :set_definition!

  def self.dashed_terms_to_undash
    %w[
      multi-polar
      non-linear
    ]
  end

  def self.spaced_terms_to_unspace
    [
      'meta crisis',
      'super organism',
      'sense making'
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
    Vterm.delete_all
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
      civilizational collapse
      climate change
      collective action
      collective intelligence
      complexity science
      conflict theory
      coordination failure
      critical infrastructure
      decision making
      dunbar number
      dystopia
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
  end

  def self.plurals
    interesting.map { |term| term.pluralize }
  end

  def linked_definition
    d = definition.strip
    d.gsub!(/‘(#{term.pluralize})’/i, %(\\0))
    d.gsub!(/‘(#{term})’/i, %(\\0)) if term.pluralize != term
    d.gsub!(/\b(#{term.pluralize})\b/i, %(<mark class="text-white">\\0</mark>))
    d.gsub!(/\b(#{term})\b/i, %(<mark class="text-white">\\0</mark>)) if term.pluralize != term
    (['metacrisis'] + ((Vterm.plurals + Vterm.interesting).uniq - ['metacrisis']) - [term, term.pluralize]).each do |t|
      d.gsub!(/\b(#{t})\b/i, %(<a href="/metacrisis/terms/#{t}">\\0</a>))
    end
    d
  end
end
