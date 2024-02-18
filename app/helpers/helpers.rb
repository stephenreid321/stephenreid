StephenReid::App.helpers do
  def timeago(x)
    %(<abbr data-toggle="tooltip" class="timeago" title="#{x.iso8601}">#{x.iso8601}</abbr>)
  end

  def audio_prompt
    p = ['You are [Stephen Reid](https://stephenreid.net). Here is information on Stephen:']
    p += BlogPost.prompt[0..1]
    p << %(## Books I've read

[Hospicing Modernity: Facing Humanity's Wrongs and the Implications for Social Activism](https://www.goodreads.com/book/show/57425775-hospicing-modernity) by Vanessa Machado De Oliveira

[At Work in the Ruins: Finding Our Place in the Time of Science, Climate Change, Pandemics and All the Other Emergencies](https://www.goodreads.com/book/show/66054459-at-work-in-the-ruins) by Dougald Hine

[Wetiko: Healing the Mind-Virus That Plagues Our World](https://www.goodreads.com/book/show/60630705-wetiko) by Paul Levy

[Atomic Habits: An Easy & Proven Way to Build Good Habits & Break Bad Ones](https://www.goodreads.com/book/show/40121378-atomic-habits) by James Clear

[Post Capitalist Philanthropy](https://www.goodreads.com/book/show/64660069-post-capitalist-philanthropy) by Alnoor Ladha

[The Seven-Day Love Prescription](https://www.goodreads.com/book/show/63109943-the-seven-day-love-prescription) by John M. Gottman

[Holding Change: The Way of Emergent Strategy Facilitation and Mediation (Emergent Strategy Series Book 4)](https://www.goodreads.com/book/show/56415144-holding-change) by Adrienne Maree Brown

[The Red Deal: Indigenous Action to Save Our Earth](https://www.goodreads.com/book/show/57820121-the-red-deal) by The Red Nation

[A Prayer for the Crown-Shy (Monk & Robot, #2)](https://www.goodreads.com/book/show/40864030-a-prayer-for-the-crown-shy) by Becky Chambers

[A Psalm for the Wild-Built (Monk & Robot, #1)](https://www.goodreads.com/book/show/40864002-a-psalm-for-the-wild-built) by Becky Chambers)
    p << File.read("#{Padrino.root}/app/jekyll_blog/_posts/2020-03-20-karuna-journey.md").force_encoding('utf-8')
    p << %(My girlfriend's name is Laura. She lives in Stockholm, Sweden and is finishing her PhD on relational sensitivity in participatory design. We met at the Emerge conference in Berlin in 2019.)
    p << %(My best friends include Ronan Harrington, Gaia Harvey Jackson, Rita Issa and Paul Powlesland.)
    p << %(---
      Now, reply to the conversation below the line as if you were Stephen.
      Reply in the first person, not the third person.
      Do not start the reply with 'hi', 'hello', or any other greeting.
      ---)
    p
  end

  def md(slug, render: true)
    begin
      text = File.read("#{Padrino.root}/app/markdown/#{slug}.md").force_encoding('utf-8')
      text = text.gsub(/\A---(.|\n)*?---/, '')
    rescue StandardError
      text = slug
    end
    if render
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true, fenced_code_blocks: true)
      markdown.render(text)
    else
      text
    end
  end

  def front_matter(slug)
    text = File.read("#{Padrino.root}/app/markdown/#{slug}.md").force_encoding('utf-8')
    FrontMatterParser::Parser.new(:md).call(text)
  end

  def cp(slug, locals: {}, key: slug, expires: 1.hours.to_i)
    Padrino.env == :development ? partial(slug, locals: locals) : cache(key, expires: expires) { partial(slug, locals: locals) }
  end

  def current_account
    @current_account ||= Account.find(session[:account_id]) if session[:account_id]
  end

  def sign_in_required!
    halt(403) unless current_account
  end

  def tag_badge(tag, account: tag.try(:account), html_tag: 'a')
    return unless tag

    if tag.is_a?(Tag)
      name = tag.name
      bg = "background-color: #{tag.background_color}"
      c = ''
      s = ''
    else
      name = tag
      bg = 'background: none'
      c = 'text-contrast'
      s = 'font-weight: 500'
    end
    %(<#{html_tag} href="/u/#{account.username}/tags/#{name}" class="badge badge-secondary #{c}" style="#{bg}; #{s}">#{name}</#{html_tag}>)
  end
end
