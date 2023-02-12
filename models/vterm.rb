class Vterm
  include Mongoid::Document
  include Mongoid::Timestamps

  field :term, type: String
  field :definition, type: String
  field :see_also, type: String
  field :weight, type: Integer
  field :prompt, type: String

  def self.admin_fields
    {
      term: :text,
      prompt: :text_area,
      definition: :text_area,
      see_also: :text,
      weight: :number,
      network_id: :lookup
    }
  end

  belongs_to :network

  has_many :vedges_as_source, class_name: 'Vedge', inverse_of: :source, dependent: :destroy
  has_many :vedges_as_sink, class_name: 'Vedge', inverse_of: :sink, dependent: :destroy

  validates_uniqueness_of :term, scope: :network

  def videos
    ids = []
    ids += network.videos.where(text: /\b#{term}\b/i).pluck(:id)
    ids += network.videos.where(text: /\b#{term.pluralize}\b/i).pluck(:id) if term.pluralize != term
    network.videos.where(:id.in => ids)
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
    context = prompt || network.prompt
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

        #{(network.interesting - [term]).join(', ')}.

        Return the result as a comma-separated list, e.g. 'term1, term2, term3, term4, term5'.

        " }.to_json
    end

    see_also = JSON.parse(openapi_response.body)['choices'].first['text'].strip
    see_also = see_also.split(', ').map { |term| term.downcase }.select { |term| network.interesting.include?(term) && term != self.term }.join(', ')
    self.see_also = see_also
    save
  end
  handle_asynchronously :set_see_also!

  def see_also_ids
    see_also ? network.vterms.where(:term.in => see_also.split(', ')).pluck(:id) : []
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
      'meta modern',
      'meta modernism',
      'meta modernity',
      'super organism',
      'sense making',
      'hyper normal',
      'psycho technology',
      'psycho technologies'
    ]
  end

  def self.spaced_terms_to_dash
    [
      'self terminating',
      'self organizing',
      'self organization'
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

  def find_or_create_vedges
    source = self
    (network.vterms - [source]).each { |sink| network.find_or_create_vedge(source, sink) }
  end

  def linked_definition
    d = definition.strip + "\n\nSee also: #{see_also}"
    d.gsub!(/‘(#{term.pluralize})’/i, %(\\0))
    d.gsub!(/‘(#{term})’/i, %(\\0)) if term.pluralize != term
    d.gsub!(/“(#{term.pluralize})”/i, %(\\0))
    d.gsub!(/“(#{term})”/i, %(\\0)) if term.pluralize != term
    d.gsub!(/\b(#{term.pluralize})\b/i, %(<mark class="text-white">\\0</mark>))
    d.gsub!(/\b(#{term})\b/i, %(<mark class="text-white">\\0</mark>)) if term.pluralize != term
    (((network.plurals + network.interesting).uniq) - [term, term.pluralize]).each do |t|
      d.gsub!(/\b(#{t})\b/i, %(<a href="/k/#{network.slug}/terms/#{t}">\\0</a>))
    end
    d
  end
end
