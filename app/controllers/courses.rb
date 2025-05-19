StephenReid::App.controller do
  get '/courses/:slug' do # cache: true
    expires 1.hour.to_i
    @course = Course.all(filter: "{Slug} = '#{params[:slug]}'").first
    @title = @course['Name']
    erb :'courses/course', layout: false
  end
end
