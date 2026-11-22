# Readwise's archive, for the tests of what's posted from it
module ReadwiseHelpers
  # A document as Readwise lists it, archived at this time
  def archived(url, at, title: "Title of #{url}", **fields)
    { 'source_url' => url, 'title' => title, 'last_moved_at' => at.utc.iso8601 }.merge(fields.transform_keys(&:to_s))
  end

  # Readwise's archive, these links archived an hour apart, oldest first, and any other stubs
  def stub_readwise(urls, &more)
    documents = urls.each_with_index.map { |url, i| archived(url, (urls.size - i).hours.ago) }
    stub_http do |stub|
      stub.get('https://readwise.io/api/v3/list') { json('results' => documents.reverse) }
      more&.call(stub)
    end
  end
end
