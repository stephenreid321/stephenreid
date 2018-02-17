ActivateApp::App.helpers do
  
  def current_account
    @current_account ||= Account.find(session[:account_id]) if session[:account_id]
  end
   
  def sign_in_required!
    unless current_account
      flash[:notice] = 'You must sign in to access that page'
      session[:return_to] = request.url
      request.xhr? ? halt : redirect(url(:accounts, :sign_in))
    end
  end  
  
  def timeago(x)
    %Q{<abbr class="timeago" title="#{x.iso8601}">#{x}</abbr>}
  end  
  
  def f(slug)
    (if fragment = Fragment.find_by(slug: slug) and fragment.body
        "\"#{fragment.body.to_s.gsub('"','\"')}\""
      end).to_s
  end  
  
  def ef(slug, body: nil)
    if fragment = Fragment.find_by(slug: slug)
      x = body || fragment.body
      y = %Q{<small>#{timeago(fragment.updated_at)}</small>}
      x += if current_account
        %Q{ <a href="/admin/edit/Fragment/#{fragment.id}">#{y}</a>}
      else
        y
      end      
    else
      if current_account
        x = %Q{<a class="btn btn-sm btn-primary" href="/admin/new/Fragment">Create fragment</a>}
      end
    end
    x
  end
  
  def anki(slug)
    if fragment = Fragment.find_by(slug: slug)    
      # Mature 1111 Young 348 Unseen 54 Suspended (4244)
      m, mature, y, young, u, unseen, s, suspended = fragment.body.split(' ').map { |x| begin; eval(x).to_f; rescue; end }
      total = mature + young + unseen + suspended
      ef(slug, body: %Q{#{(((mature + young)/total)*100).round}% of #{total.to_i} cards})
    else
      ef(slug)
    end
  end
  
end