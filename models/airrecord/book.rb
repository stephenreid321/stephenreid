class Book < Airrecord::Table
  self.base_key = ENV['AIRTABLE_BASE_KEY']
  self.table_name = 'Books'

  def self.import
    csv = CSV.parse(open("#{Padrino.root}/app/assets/goodreads_library_export.csv"), headers: true)

    csv.each do |row|
      puts row['Title']
      book = Book.all(filter: "{Book Id} = #{row['Book Id']}").first
      if book
        book['Date Added'] = row['Date Added']
        book['Date Read'] = row['Date Read']
        book['My Rating'] = row['My Rating'].to_f
        book['Average Rating'] = row['Average Rating'].to_f
        book['Bookshelves'] = row['Bookshelves']
        book['Bookshelves with positions'] = row['Bookshelves with positions']
        book['Exclusive Shelf'] = row['Exclusive Shelf']
        # book['ISBN'] = row['ISBN'].gsub('=', '').gsub('"', '')
        # book['ISBN13'] = row['ISBN13'].gsub('=', '').gsub('"', '')
        book.save
      else
        puts "creating #{row['Title']}"
        data = row.to_h
        data['ISBN'] = data['ISBN'].gsub('=', '').gsub('"', '')
        data['ISBN13'] = data['ISBN13'].gsub('=', '').gsub('"', '')
        data = data.map do |k, v|
          if v.blank?
            [k, nil]
          elsif !k.in?(%w[ISBN ISBN13])
            [k, v.match?(/^\d+(\.\d+)?$/) ? v.to_f : v]
          else
            [k, v]
          end
        end.to_h
        puts data
        book = Book.new(data)
        book.save
        book.grab_image!
      end
    end
    #  end
    csv_ids = csv.map { |row| row['Book Id'].to_i }
    book_ids = Book.all.map { |book| book['Book Id'] }
    (book_ids - csv_ids).each do |id|
      book = Book.all(filter: "{Book Id} = #{id}").first
      puts "#{book['Title']} (#{book['Book Id']}) no longer in CSV"
      # book.destroy
    end
  end

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
    if book['Full text']
      prompt = "Please summarise this book:\n\n#{book['Title']} by #{book['Author']}\n\n#{URI.open(book['Full text'][0]['url']).read}"
      gemini = GEMINI_FLASH
    else
      prompt = "Please provide a comprehensive summary of the book #{book['Title']} by #{book['Author']}"
      gemini = GEMINI_PRO
    end

    response = gemini.generate_content(
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
