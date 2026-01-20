module Prompt
  def self.prompt(book_summaries: false)
    p = [
      %(## Short bio in the third person),
      File.read("#{Padrino.root}/app/markdown/bio.md").force_encoding('utf-8'),
      %(## Training and teachers),
      File.read("#{Padrino.root}/app/markdown/training.md").force_encoding('utf-8'),
      %(## Speaking engagements),
      SpeakingEngagement.all(filter: '{Hidden} = 0', sort: { 'Date' => 'desc' }).map { |speaking_engagement| "#{[speaking_engagement['Date'], speaking_engagement['Location'], speaking_engagement['Organisation Name']].compact.join(', ')}: #{speaking_engagement['Name']}" }.join("\n\n"),
      # %(## Diet),
      # File.read("#{Padrino.root}/app/markdown/diet.md").force_encoding('utf-8'),
      # %(## AI consulting),
      # File.read("#{Padrino.root}/app/markdown/ai_consulting.md").force_encoding('utf-8'),
      # %(## Facilitation),
      # File.read("#{Padrino.root}/app/markdown/facilitation.md").force_encoding('utf-8'),
      %(## Life as Practice),
      File.read("#{Padrino.root}/app/markdown/life_as_practice.md").force_encoding('utf-8'),      
      %(## Coaching),
      File.read("#{Padrino.root}/app/markdown/coaching.md").force_encoding('utf-8'),
      %(## Content I've shared recently),
      Post.all(filter: "IS_AFTER({Created at}, '#{3.months.ago.to_s(:db)}')", sort: { 'Created at' => 'desc' }).map { |post| "[#{post['Title']}](#{post['Link']}), #{post['Created at']}\n#{post['Body']}" }.join("\n\n")
    ]
    if book_summaries
      p << %(## Books I've read, with summaries)
      p << Book.all(sort: { 'Date Read' => 'desc' }, filter: "{Date Read} >= '2018-01-01'").map { |b| "### #{b['Title']} by #{b['Author']} (read #{b['Date Read']})\n\n#{b['Summary'].blank? ? '(summary missing)' : b['Summary'].split("\n\n")[1..-1].join("\n\n")}" }.join("\n\n")
    else
      p << %(## Books I've read)
      p << Book.all(sort: { 'Date Read' => 'desc' }, filter: "{Date Read} >= '2018-01-01'").map { |b| "#{b['Title']} by #{b['Author']} (read #{b['Date Read']})\n" }.join("\n")
    end
    # Event descriptions
    # Course notes
    p
  end
end
