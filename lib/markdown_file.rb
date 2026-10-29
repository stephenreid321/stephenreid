# The markdown files in app/markdown, by name
module MarkdownFile
  def self.read(name)
    File.read("#{Padrino.root}/app/markdown/#{name}.md", encoding: 'UTF-8')
  end

  # A new renderer each time, as Redcarpet's aren't safe to share between Puma's threads
  def self.html(name)
    Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true, fenced_code_blocks: true).render(read(name))
  end
end
