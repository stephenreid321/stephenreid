require 'csv'

%w[speaking_engagements courses films].each do |name|
  path = "#{PADRINO_ROOT}/data/#{name}.csv"
  Object.const_set(
    name.upcase,
    CSV.read(path, headers: true).map do |row|
      row.to_h.transform_keys(&:to_sym).transform_values { |v| v.nil? || v.empty? ? nil : v }
    end.freeze
  )
end

cover_dir = "#{PADRINO_ROOT}/app/assets/images/books"
BOOKS = CSV.read("#{PADRINO_ROOT}/data/goodreads_library_export.csv", headers: true).map do |row|
  book = row.to_h.transform_keys { |k| k.to_s.downcase.gsub(/[^\w]+/, '_').gsub(/\A_|_\z/, '').to_sym }
  book.transform_values! { |v| v.nil? || v.to_s.empty? ? nil : v }

  %i[isbn isbn13].each do |key|
    book[key] = book[key].gsub(/[="]/, '') if book[key]
  end
  %i[date_read date_added].each do |key|
    book[key] = book[key].tr('/', '-') if book[key]
  end

  book[:slug] = book[:title].to_s.parameterize

  book_id = book[:book_id].to_s
  book[:cover_image] = "/images/books/#{book_id}.jpg" if File.exist?("#{cover_dir}/#{book_id}.jpg")

  book
end.freeze
