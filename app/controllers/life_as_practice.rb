StephenReid::App.controller do
  get '/life-as-practice', cache: true do
    expires 1.hour.to_i
    @og_image = 'https://dandelion.ams3.cdn.digitaloceanspaces.com/2023/06/14/16/01/05/e1370ec2-47d4-4d66-857e-2ec1cd482d38/file'
    @title = 'Life as Practice'
    erb :'life_as_practice/life_as_practice'
  end

  get '/life-as-practice/doc', cache: true do
    expires 1.hour.to_i
    @og_image = 'https://dandelion.ams3.cdn.digitaloceanspaces.com/2023/06/14/16/01/05/e1370ec2-47d4-4d66-857e-2ec1cd482d38/file'
    @stylesheet = 'light'
    @title = 'Life as Practice'
    erb :'life_as_practice/life_as_practice_doc', layout: :minimal
  end

  get '/life-as-practice/thanks', cache: true do
    expires 1.hour.to_i
    @og_image = 'https://dandelion.ams3.cdn.digitaloceanspaces.com/2023/06/14/16/01/05/e1370ec2-47d4-4d66-857e-2ec1cd482d38/file'
    @title = 'Life as Practice'
    erb :'life_as_practice/life_as_practice_thanks'
  end
end
