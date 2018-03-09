ActivateApp::App.controller do
  
  before do
    sign_in_required!     
  end
    
  get '/crypto' do        
    erb :crypto
  end
    
  get '/crypto/enter' do
    MyBinance.enter
    redirect '/crypto'
  end  
  
  get '/crypto/exit' do
    MyBinance.exit
    redirect '/crypto'
  end
   
end