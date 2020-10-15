class Jekyll::Converters::Markdown::CustomMarkdownProcessor
  def initialize(config)
    require 'redcarpet'
    @config = config
  end

  def convert(text)
    text = text.gsub(/\A---(.|\n)*?---/, '')
    text = text.gsub(/==(.|\n)*?==/) { |m| "<mark>#{m[2..-3]}</mark>" }
    markdown = ::Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    markdown.render(text)
  end
end
