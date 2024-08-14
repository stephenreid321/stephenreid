StephenReid::App.controller do
  get '/tao-te-ching' do
    redirect '/tao-te-ching/1'
    # redirect 'https://rarible.com/tao-te-ching'
    # @title = 'Tao Te Ching'
    # @favicon = 'tao-sq.png'
    # @og_image = "#{ENV['BASE_URI']}/images/fish.jpg"
    # @og_desc = ''
    # erb :tao
  end

  get '/tao-te-ching/:i' do
    @title = "Verse #{params[:i]} · Tao Te Ching"
    @favicon = 'tao-sq.png'
    verse = Verse.all(filter: "{Verse} = #{params[:i]}").first
    not_found if verse.nil?
    @og_image = verse['Images'].first['thumbnails']['full']['url']
    @og_desc = verse['Text'].split("\n\n").first
    erb :tao
  end
end
