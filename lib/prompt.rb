module Prompt
  def self.prompt(book_summaries: false)
    sections = [
      {
        title: 'Short bio in the third person',
        content: File.read("#{Padrino.root}/app/markdown/bio.md").force_encoding('utf-8')
      },
      {
        title: 'Training and teachers',
        content: File.read("#{Padrino.root}/app/markdown/training.md").force_encoding('utf-8')
      },
      {
        title: 'Speaking engagements',
        content: SpeakingEngagement.all(filter: '{Hidden} = 0', sort: { 'Date' => 'desc' }).map { |speaking_engagement| "#{[speaking_engagement['Date'], speaking_engagement['Location'], speaking_engagement['Organisation Name']].compact.join(', ')}: #{speaking_engagement['Name']}" }.join("\n\n")
      },
      {
        title: 'Life as Practice',
        content: File.read("#{Padrino.root}/app/markdown/life_as_practice.md").force_encoding('utf-8')
      },
      {
        title: 'Coaching',
        content: File.read("#{Padrino.root}/app/markdown/coaching.md").force_encoding('utf-8')
      },
      {
        title: "Content I've shared recently",
        posts: Post.all(filter: "IS_AFTER({Created at}, '#{3.months.ago.to_s(:db)}')", sort: { 'Created at' => 'desc' }).map { |post| { title: post['Title'], link: post['Link'], date: post['Created at'], body: post['Body'] } }
      }
    ]

    if book_summaries
      sections << {
        title: "Books I've read, with summaries",
        books: Book.all(sort: { 'Date Read' => 'desc' }, filter: "{Date Read} >= '2018-01-01'").map { |b| { title: b['Title'], author: b['Author'], date_read: b['Date Read'], summary: b['Summary'].blank? ? '(summary missing)' : b['Summary'].split("\n\n")[1..-1].join("\n\n") } }
      }
    else
      sections << {
        title: "Books I've read",
        books: Book.all(sort: { 'Date Read' => 'desc' }, filter: "{Date Read} >= '2018-01-01'").map { |b| { title: b['Title'], author: b['Author'], date_read: b['Date Read'] } }
      }
    end

    { document: { section: sections } }
  end

  def self.markdown(book_summaries: false)
    data = prompt(book_summaries: book_summaries)
    sections = data[:document][:section]

    sections.map do |section|
      result = ["## #{section[:title]}"]

      if section[:content]
        result << section[:content]
      elsif section[:posts]
        result << section[:posts].map { |post| "[#{post[:title]}](#{post[:link]}), #{post[:date]}\n#{post[:body]}" }.join("\n\n")
      elsif section[:books]
        if section[:title].include?('summaries')
          result << section[:books].map { |b| "### #{b[:title]} by #{b[:author]} (read #{b[:date_read]})\n\n#{b[:summary]}" }.join("\n\n")
        else
          result << section[:books].map { |b| "#{b[:title]} by #{b[:author]} (read #{b[:date_read]})\n" }.join("\n")
        end
      end

      result.join("\n\n")
    end
  end

  def self.xml(book_summaries: false)
    data = prompt(book_summaries: book_summaries)
    sections = data[:document][:section]

    sections.map do |section|
      section_hash = { title: section[:title] }
      
      if section[:content]
        section_hash[:content] = section[:content]
      elsif section[:posts]
        section_hash[:post] = section[:posts]
      elsif section[:books]
        section_hash[:book] = section[:books]
      end
      
      section_hash.to_xml(root: 'section', skip_instruct: true)
    end
  end
end
