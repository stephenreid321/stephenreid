StephenReid::App.controller do
  get '/life-as-practice' do # cache: true
    # expires 1.hour.to_i
    # @og_image = 'https://dandelion.ams3.cdn.digitaloceanspaces.com/2023/06/14/16/01/05/e1370ec2-47d4-4d66-857e-2ec1cd482d38/file'
    # @title = 'Life as Practice'
    # erb :'life_as_practice/life_as_practice'
    redirect 'https://docs.google.com/document/d/1DIiTAPJzC0_Bn0Zd8zbBkWo0jHNpT9xKGiy8m2UyGgE/edit'
  end

  get '/life-as-practice/doc' do # cache: true
    # expires 1.hour.to_i
    # @og_image = 'https://dandelion.ams3.cdn.digitaloceanspaces.com/2023/06/14/16/01/05/e1370ec2-47d4-4d66-857e-2ec1cd482d38/file'
    # @stylesheet = 'light'
    # @title = 'Life as Practice'
    # erb :'life_as_practice/life_as_practice_doc', layout: :minimal
    redirect 'https://docs.google.com/document/d/1DIiTAPJzC0_Bn0Zd8zbBkWo0jHNpT9xKGiy8m2UyGgE/edit'
  end

  get '/life-as-practice/thanks' do # cache: true
    # expires 1.hour.to_i
    # @og_image = 'https://dandelion.ams3.cdn.digitaloceanspaces.com/2023/06/14/16/01/05/e1370ec2-47d4-4d66-857e-2ec1cd482d38/file'
    # @title = 'Life as Practice'
    # erb :'life_as_practice/life_as_practice_thanks'
    redirect 'https://docs.google.com/document/d/1DIiTAPJzC0_Bn0Zd8zbBkWo0jHNpT9xKGiy8m2UyGgE/edit'
  end
end
