StephenReid::App.controller do
  get '/iconomi', cache: true do
    expires 6.hours.to_i
    @title = 'ICONOMI strategy evaluator'
    erb :'iconomi/iconomi'
  end

  get '/metastrategy' do
    @title = 'Metastrategy'
    erb :'iconomi/metastrategy'
  end

  get '/metastrategy/table' do
    partial :'iconomi/metastrategy'
  end
end
