class Book < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Books'

  # https://www.goodreads.com/review/import
  def self.summarise!
    books = Book.all(filter: "AND({Summary} = '', {Dandelion} != '')")
    count = books.length
    books.each_with_index do |book, i|
      puts "#{book['Title']} (#{i + 1}/#{count})"
      begin
        book.summarise!
      rescue StandardError => e
        puts e
      end
    end
  end

  def self.grab_images!
    books = Book.all(filter: "{Cover image} = ''")
    count = books.length
    books.each_with_index do |book, i|
      puts "#{book['Title']} (#{i + 1}/#{count})"
      begin
        book.grab_image!
      rescue StandardError => e
        puts e
      end
    end
  end

  def grab_image!
    book = self
    agent = Mechanize.new
    response = agent.get("https://www.goodreads.com/book/show/#{book['Book Id']}")
    book['Cover image'] = [{ url: response.at_css('.BookCover__image img')['src'] }]
    book.save
  end

  def summarise!
    book = self
    prompt = book['Full text'] ? "Please summarise this book:\n\n#{book['Title']} by #{book['Author']}\n\n#{URI.open(book['Full text'][0]['url']).read}" : "Please provide a comprehensive summary of the book #{book['Title']} by #{book['Author']}"

    response = GEMINI.generate_content(
      {
        contents: { role: 'user', parts: { text: prompt } },
        generationConfig: { maxOutputTokens: 8192 }
      }
    )
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')

    # client = Anthropic::Client.new
    # response = client.messages(
    #   parameters: {
    #     # model: 'claude-3-haiku-20240307',
    #     model: 'claude-3-opus-20240229',
    #     messages: [
    #       { role: 'user', content: prompt }
    #     ],
    #     max_tokens: 4096
    #   }
    # )
    # content = response['content'].first['text']

    puts "#{content}\n\n"
    book['Summary'] = content
    book.save
  end
end
