namespace :blyg do
  desc 'Publish to the blyg the links archived in Readwise in the last week since the newest one on it, as bluesky:post posts them to Bluesky (needs READWISE_ACCESS_TOKEN and BLYG_ACCESS_TOKEN)'
  task post: :environment do
    Blyg.post_from_readwise
  end

  desc 'Download the Blygger Studio release in cloudflare/blyg/release.json and extract its Worker into cloudflare/blyg, for wrangler deploy. VERSION=x.y.z moves release.json to that release'
  task download: :environment do
    puts BlyggerRelease.next_steps(BlyggerRelease.download(version: ENV.fetch('VERSION', nil)))
  end
end
