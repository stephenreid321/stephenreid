# Everything about Stephen as one markdown document, for /context
module Context
  def self.markdown(notes_limit: nil, posts_limit: nil)
    {
      'Short bio in the third person' => File.read("#{Padrino.root}/app/markdown/bio.md", encoding: 'UTF-8'),
      'Training and teachers' => File.read("#{Padrino.root}/app/markdown/training.md", encoding: 'UTF-8'),
      'Speaking engagements' => SPEAKING_ENGAGEMENTS.reject { |s| s[:hidden] }.map do |s|
        name = s[:url].present? ? "[#{s[:name]}](#{s[:url]})" : s[:name]
        "#{[s[:date], s[:location]].compact.join(', ')}: #{name}"
      end.join("\n\n"),
      "Books I've read" => BOOKS.select { |b| b[:date_read] && b[:date_read] >= '2018-01-01' }.sort_by { |b| b[:date_read] }.reverse.map do |b|
        "#{b[:title]} by #{b[:author]} (read #{b[:date_read]})\n"
      end.join("\n"),
      'Substack notes' => SubstackNote.markdown_export(limit: notes_limit),
      'Substack posts' => SubstackPost.markdown_export(limit: posts_limit)
    }.map { |title, content| "## #{title}\n\n#{content}" }.join("\n\n")
  end
end
