StephenReid::App.controller do
  get '/books' do
    @title = 'Books'
    erb :books
  end

  get '/books/:slug' do
    @book = Book.all(filter: "{Slug} = '#{params[:slug]}'").first || not_found
    redirect("https://www.goodreads.com/book/show/#{@book['Book Id']}") if @book['Summary'].blank?
    @title = @book['Title']
    erb :book
  end
end
