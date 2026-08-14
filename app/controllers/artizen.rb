StephenReid::App.controller do
  before %r{\A/artizen} do
    @stylesheet = 'light'
  end

  get '/artizen' do
    @container_class = 'container-fluid'
    @title = 'Artizen'
    @og_desc = 'Fund and project leaderboards from Artizen'
    @data = Artizen.leaderboard(season_number: params[:season])
    @seasons = @data[:seasons]
    @season = @data[:season]
    @drives = @data[:drives] || []
    @projects = @data[:projects]
    @funds = @data[:funds]
    @artizen_error = @data[:error]
    @title = @season ? "Artizen · #{@season[:title]}" : 'Artizen'

    erb :'artizen/leaderboards'
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
