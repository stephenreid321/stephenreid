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
        book.set_additional_info! unless book['Genres'] && book['Number of Ratings'] && book['Cover image']
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
        book.set_additional_info!
        # book.save
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

  def self.set_additional_info!
    # Create a thread pool with a fixed number of threads (e.g., 5)
    pool = Concurrent::FixedThreadPool.new(100)

    futures = []

    Book.all.each do |book|
      futures << Concurrent::Future.execute(executor: pool) do
        puts book['Title']
        book.set_additional_info! unless book['Genres'] && book['Number of Ratings'] && book['Cover image']
      end
    end

    # Wait for all futures to complete
    futures.each(&:wait)

    # Shutdown the pool after work is done
    pool.shutdown
    pool.wait_for_termination
  end

  def set_additional_info!
    book = self
    a = Mechanize.new
    page = a.get("https://www.goodreads.com/book/show/#{book['Book Id']}")
    book['Genres'] = page.search('[data-testid=genresList] .Button__labelItem').map { |el| el.text }.reject { |g| g.starts_with?('...') }.join(', ')
    book['Number of Ratings'] = page.search('[data-testid=ratingsCount]').text.gsub(',', '').to_i
    if img = page.at_css('.BookCover__image img')
      book['Cover image'] = [{ url: img['src'] }]
    end
    book.save
  end
end
