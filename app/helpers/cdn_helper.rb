StephenReid::App.helpers do
  # A script or stylesheet from jsDelivr: an npm package's file, at the version in frontend/package.json, or a URL. Its
  # hash from frontend/integrity.json is its integrity attribute, so the browser won't run it if it changes
  def cdn_tag(package_or_url, file = nil, **attributes)
    url = file ? FRONTEND_NPM_URL.call(package_or_url, file) : package_or_url
    attributes = attributes.merge(integrity: FRONTEND_INTEGRITY.fetch(url), crossorigin: 'anonymous')
    if url.end_with?('.css')
      tag(:link, attributes.merge(rel: 'stylesheet', href: url))
    else
      content_tag(:script, '', attributes.merge(src: url))
    end
  end
end
