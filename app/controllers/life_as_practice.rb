StephenReid::App.controller do
  get '/life-as-practice', cache: true do
    expires 1.hour.to_i
    @og_image = 'https://autopia.s3.amazonaws.com/2022/07/13/11/36/03/96394251-0af2-4126-a99f-2b127a13bff8/Untitled-6.jpg'
    @title = 'Life as Practice'
    erb :life_as_practice
  end

  get '/life-as-practice/doc', cache: true do
    expires 1.hour.to_i
    @og_image = 'https://autopia.s3.amazonaws.com/2022/07/13/11/36/03/96394251-0af2-4126-a99f-2b127a13bff8/Untitled-6.jpg'
    @stylesheet = 'light'
    @title = 'Life as Practice'
    erb :life_as_practice_doc, layout: :minimal
  end

  get '/life-as-practice/thanks', cache: true do
    expires 1.hour.to_i
    @og_image = 'https://autopia.s3.amazonaws.com/2022/07/13/11/36/03/96394251-0af2-4126-a99f-2b127a13bff8/Untitled-6.jpg'
    @title = 'Life as Practice'
    erb :life_as_practice_thanks
  end
end
