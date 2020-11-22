class Jekyll::Converters::Markdown::CustomMarkdownProcessor
  def initialize(config)
    require 'redcarpet'
    @config = config
  end

  def convert(text)
    text.gsub!(/\A---(.|\n)*?---/, '')
    text.gsub!(/==(.|\n)*?==/) { |m| "<mark>#{m[2..-3]}</mark>" }
    ::Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true).render(text)
  end
end
