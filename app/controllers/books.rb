StephenReid::App.controller do
  get '/books' do
    @title = 'Books'
    erb :books
  end

  get '/books/:slug' do
    @book = Book.all(filter: "{Slug} = '#{params[:slug]}'").first || not_found
    @title = @book['Title']
    erb :book
  end
end
