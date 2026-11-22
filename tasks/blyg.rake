namespace :blyg do
  desc 'Publish to the blyg the links archived in Readwise in the last week since the newest one on it, as bluesky:post posts them to Bluesky (needs READWISE_ACCESS_TOKEN and BLYG_ACCESS_TOKEN)'
  task post: :environment do
    blyg = Blyg.new
    # Only those archived after the newest on the blyg already, so a link never lands above one archived after it: one
    # missed is left out rather than posted out of order
    Readwise.to_post(Blyg.recent_link_urls, after_newest: true).each do |r|
      puts r['source_url']
      blyg.post_link(url: r['source_url'], title: r['title'].presence || r['source_url'], author: r['author'])
    end
  end

  desc 'Download the Blygger Studio release in cloudflare/blyg/release.json and extract its Worker into cloudflare/blyg, for wrangler deploy. VERSION=x.y.z moves release.json to that release'
  task download: :environment do
    version = BlyggerRelease.download(version: ENV.fetch('VERSION', nil))
    puts "Blygger Studio #{version} is in cloudflare/blyg. Read the changelog's Migrations: lines since the last release, then from cloudflare/blyg:"
    puts '  env -u CLOUDFLARE_API_TOKEN npx wrangler d1 migrations apply DB --remote'
    puts '  env -u CLOUDFLARE_API_TOKEN node normalize-import-dates.mjs --remote'
    puts '  env -u CLOUDFLARE_API_TOKEN npx wrangler deploy'
  end
end
