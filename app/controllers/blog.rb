ActivateApp::App.controllers :blog do
    
  get :index do
    @blog_posts = BlogPost.order_by(:created_at.desc).per_page(5).page(params[:page])
    erb :'blog/index'
  end
  
  get :post, :with => :slug do 
    @blog_post = BlogPost.find_by(slug: params[:slug]) || not_found
    @title = @blog_post.title
    erb :'blog/post'
  end  
  
end
