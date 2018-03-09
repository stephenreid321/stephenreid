ActivateApp::App.controller do
  
  before do
    sign_in_required!     
  end
    
  get '/crypto' do        
    MyBinance.balances(true)
    erb :crypto
  end
    
  post '/crypto/enter' do
    MyBinance.enter
    redirect '/crypto'
  end  
  
  post '/crypto/exit' do
    MyBinance.exit
    redirect '/crypto'
  end
   
end