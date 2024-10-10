StephenReid::App.controller do
  get '/whatsapp' do
    params[:hub_challenge]
  end
end
