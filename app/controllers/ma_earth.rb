StephenReid::App.controller do
  get '/ma-earth' do
    @title = 'Ma Earth'
    @container_class = 'container-fluid'
    erb :ma_earth
  end

  get '/ma-earth/:slug' do
    @post = @mapod = Mapod.all(filter: "{Slug} = '#{params[:slug]}'").first || not_found
    @title = @mapod['Title']
    erb :mapod
  end
end
