StephenReid::App.controller do
  before %r{\A/artizen} do
    @stylesheet = 'light'
  end

  get '/artizen' do
    qs = params[:season].present? ? "?season=#{params[:season]}" : ''
    redirect "/artizen/projects#{qs}"
  end

  get '/artizen/projects' do
    load_artizen_board
    @tab = :projects
    erb :'artizen/projects'
  end

  get '/artizen/drives' do
    load_artizen_board
    @tab = :drives
    erb :'artizen/drives'
  end

  get '/artizen/funds' do
    load_artizen_board
    @tab = :funds
    erb :'artizen/funds'
  end

  get '/artizen/projects/:slug' do
    @project = Artizen.project(params[:slug]) || not_found
    @title = @project[:name]
    @og_desc = @project[:logline] || "Artizen project: #{@project[:name]}"
    @og_image = @project[:image] if @project[:image]
    erb :'artizen/project'
  end

  get '/artizen/funds/:slug' do
    @fund = Artizen.fund(params[:slug]) || not_found
    @title = @fund[:name]
    @og_desc = @fund[:subtitle] || @fund[:for_title] || "Artizen fund: #{@fund[:name]}"
    @og_image = @fund[:image] if @fund[:image]
    erb :'artizen/fund'
  end
end
