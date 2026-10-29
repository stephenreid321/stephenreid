StephenReid::App.helpers do
  def timeago(x)
    %(<relative-time datetime="#{x.iso8601}">#{x.iso8601}</relative-time>)
  end

  def md(name)
    MarkdownFile.html(name)
  end

  def admin?
    session[:admin] == true
  end

  def sign_in_required!
    halt(403) unless admin?
  end

  def blanks_to_nils!(hash)
    hash.each do |k, v|
      if v.blank?
        hash[k] = nil
      elsif v.is_a? Array
        v.each_with_index { |x, i| v[i] = nil if x.blank? }.compact!
      elsif v.is_a? Hash
        blanks_to_nils!(v)
      end
    end
  end
end
