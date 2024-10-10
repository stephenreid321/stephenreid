StephenReid::App.controller do
  get '/whatsapp' do
    params[:'hub.challenge']
  end
end
