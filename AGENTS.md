This is a static site built with Jekyll and served by GitHub Pages. There's no server and no database.

- `site/` is Jekyll's source: pages, `_layouts`, `_includes` (the markdown the pages show is in `_includes/markdown`), `_data` (YAML) and the assets, which are served at the root (`/images`, `/javascripts`, `/stylesheets`)
- `site/_plugins/site.rb` hands the templates their data, adds the `cdn_tag` and `cdn_dependencies` Liquid tags, and makes the pages that have no template of their own: the courses' notes, the `.txt` exports and the redirects (`REDIRECTS`, plus `/books/<slug>` to Goodreads)
- `lib/` is plain Ruby, loaded by `config/boot.rb` for the rake tasks and the plugin. Templates can't run Ruby, so work anything out there (as `lib/iconomi_pages.rb` does for the ICONOMI pages) and hand the template the result

`rake site:serve` serves the site at http://localhost:4000, rebuilding as files change; `rake site:build` builds it into `_site`.

## Data

- `data/*.csv` is the site's own data, committed: books, films, courses and speaking engagements. So is `data/iconomi/`, what's been decided by hand about ICONOMI's strategies and assets (`strategies.csv`: status; `assets.csv`: status, colour; `multipliers.csv`: the assets Metastrategy weights up or down, and by how much)
- `data/fetched/` is what the site shows from other sites, as JSON (`lib/fetched.rb`). It isn't committed: `rake data:fetch` fetches it (Substack and ICONOMI need their keys in the environment; `rake data:public` fetches what needs none), and `site.yml` keeps it between builds in the Actions cache. Except Substack's: its Cloudflare turns away GitHub's runners, so `substack_notes.json` and `substack_posts.json` are committed, by `substack.yml`, which runs on a self-hosted runner on Stephen's Mac (`~/actions-runner-stephenreid`, label `mac`). Or run `rake data:substack` here and commit them
- `data/goodreads_library_export.csv` is Goodreads' library export, committed. Goodreads has no API for it any more, so `goodreads.yml` exports it daily on the same self-hosted runner, as a signed-in browser would (`lib/goodreads.rb`), with the `GOODREADS_COOKIE` secret: the whole Cookie header of a request to goodreads.com from a browser signed in as Stephen. When Goodreads signs that session out, the workflow fails saying so: copy a fresh header into the secret. Or run `rake data:goodreads` here with it in the environment and commit the CSV. The book covers in `site/images/books` are still added by hand
- `rake data:iconomi` fetches every strategy on ICONOMI, unlisted ones too. Its API lists only those it features (`/v1/strategies`), so the tickers come from its site's websocket as well (`Iconomi.strategy_tickers`, undocumented), and from `data/iconomi/strategies.csv`
- Metastrategy's number of assets is the `NUMBER_OF_ASSETS` Actions variable
- Dandelion (`symbiota-coop/dandelion`'s `lib/library.rb` and `app/helpers/library_helpers.rb`) reads `data/goodreads_library_export.csv`, `data/dandelion_books.csv` and `data/films.csv` from master, and their images from `site/images`, for its /books and /films. Keep those paths, or change Dandelion with them

## Workflows

Each is named in the Actions tab for what it does: Build and deploy the site (`site.yml`), Rebalance Metastrategy (`iconomi-rebalance.yml`), Verify the new ICONOMI strategies and assets (`iconomi-verify.yml`), Post to Bluesky (`bluesky.yml`), Lint (`lint.yml`), Fetch from Substack (`substack.yml`) and Export from Goodreads (`goodreads.yml`).

- `site.yml` builds the site and deploys it to Pages: on each push to master, from the last build's data, and every three hours (or by hand) with fresh data.
- `iconomi-rebalance.yml` rebalances Metastrategy on ICONOMI, what Heroku's scheduler did: Fridays at 17:00 Central European time, when the `ICONOMI_REBALANCE` variable is `true` (by hand, whatever it says)
- `iconomi-verify.yml` marks strategies and assets with no status as verified and commits that, as the old admin page's Verify did (by hand)
- `bluesky.yml` posts the links archived in Readwise in the last week to Bluesky (every three hours)
- `lint.yml` runs the linters (`script/lint`) on each push and pull request. It doesn't hold up a deploy: `site.yml` builds and deploys whatever it says
- None has a GitHub schedule (`on: schedule`), which GitHub treats as best-effort: when it's busy it starts runs hours late or not at all. A Cloudflare Worker (`cloudflare/worker.js`, its cron in `cloudflare/wrangler.jsonc`) starts each scheduled run on time with `workflow_dispatch`, by the clock in Stockholm: `substack.yml`, `bluesky.yml` and `site.yml` every three hours, `goodreads.yml` daily at 06:00, and `iconomi-rebalance.yml` on Fridays at 17:00 (with `scheduled`, so only while `ICONOMI_REBALANCE` is `true`). It wakes on the hour, and all that's due then starts together. To change when something runs, change `RUNS` in `worker.js` and deploy it from `cloudflare/`: `npm ci`, then `npx wrangler deploy`. Its `GITHUB_TOKEN` secret (`npx wrangler secret put GITHUB_TOKEN`) is a fine-grained token for this repo with Actions: Read and write. When it expires, nothing scheduled runs and the Worker's invocations fail in Cloudflare's dashboard: make a new one and put it in the secret

## Committing

Commit only the changes you made: stage your files by name rather than with `git add -A` or `git commit -a`.

`script/lint` runs our linters, RuboCop, ESLint and zizmor, each on the files of its kind. CI's lint job (`.github/workflows/lint.yml`) runs it too, so it is the one place their commands and flags are set: change a linter's flags or add a linter there, not in the workflow. Run it on the files you added or changed, and fix what it reports:

```bash
script/lint <files>
```

If a linter's config is among them (`.rubocop.yml`, `eslint.config.mjs`, `package.json`), it runs that linter on everything, as CI does; `script/lint --all` runs them all, and `--only <linter>` just one. Run `npm ci` first if `node_modules` is missing, and install uv (https://docs.astral.sh/uv/) if `uvx` is.

The pre-commit hook (`.githooks/pre-commit`) runs `script/lint --staged`, which lints the staged version of each staged file. Git runs it once `core.hooksPath` is `.githooks`: run `git config core.hooksPath .githooks` once in each checkout. Never skip it with `--no-verify`.

## Stylesheets

The site has two themes, `dark` and `light` (`?stylesheet=light`), each `site/stylesheets/<theme>.scss`: the theme's Bootstrap variables, then `_settings.scss` (variables both share), Bootstrap, and `_core.scss` (styles both share). Style with Bootstrap variables where one exists, rather than overriding its classes. Never edit the compiled `dark.css` and `light.css`: change the Sass and run `rake stylesheets:build` (needs Node), which compiles both with Dart Sass and Bootstrap at the version in `config/frontend_package.json`, so the CSS and Bootstrap's JavaScript always match. Commit the compiled CSS with its source.

Markup uses Bootstrap 5: `data-bs-*` attributes, `ms-*`/`me-*`, `text-start`/`text-end`, `text-bg-*` badges and `visually-hidden`.

## Dependencies

Cooldown: never use a gem or JS package version released less than 7 days ago. This guards against supply-chain attacks on freshly published versions. If a version that was just released can't be found, that's why: wait until it's a week old rather than removing or shortening the cooldown.

- `rake stylesheets:build` installs Bootstrap and Dart Sass with `npm install --before` set to 7 days ago, and pins Dart Sass's version
- Gems: the Gemfile's source has `cooldown: 7`, so Bundler (4 or later) enforces it
- GitHub Actions are pinned to a commit of a release at least 7 days old, with the release as a comment (zizmor's `unpinned-uses`). zizmor's own version is in `script/lint`, and uv's in `.github/workflows/lint.yml`
- The self-hosted runner on Stephen's Mac (`~/actions-runner-stephenreid`) is configured with `--disableupdate`, so it doesn't update itself to each release the day it's out. GitHub wants such a runner updated within 30 days of a new release, or it may stop sending it jobs: `substack.yml`'s runs then wait, and the site keeps the notes and posts last committed. So when a new release of `actions/runner` is out, update it by hand to the newest release at least 7 days old (`config.sh` registered it, and an update keeps that):

  ```bash
  V=2.338.2  # the release, at least 7 days old
  F=actions-runner-osx-arm64-$V.tar.gz
  cd ~/actions-runner-stephenreid
  curl -sSLo $F https://github.com/actions/runner/releases/download/v$V/$F
  # Compare with the osx-arm64 SHA in the release's notes before going on
  gh api repos/actions/runner/releases/tags/v$V --jq .body | grep -o '<!-- BEGIN SHA osx-arm64 -->[0-9a-f]*'
  shasum -a 256 $F
  ./svc.sh stop && tar xzf $F && rm $F && ./svc.sh start
  ./bin/Runner.Listener --version
  ```
- `cloudflare/package.json` is only Wrangler, pinned, installed from its `package-lock.json` (`npm ci`) like the root's. Its install scripts (esbuild's, workerd's) are left unapproved: `wrangler deploy` doesn't need them
- The root `package.json` is only linters (ESLint, `eslint.config.mjs`). It installs from `package-lock.json` (`npm ci`): pin exact versions, and when adding or bumping one run `npm install --before=<the date a week ago>` so its own dependencies are a week old too
- The packages the site loads from jsDelivr have their versions in `config/frontend_package.json`, and only there: nothing installs them, `config/frontend_dependencies.rb` reads them. `FRONTEND_DEPENDENCIES` there lists the packages every page loads and their files; a page that needs one of its own loads it with `{% cdn_tag 'package', 'path/file.js' %}`. Load a file the package ships: jsDelivr minifies a `.min` file a package lacks on the fly, and that output can change
- `cdn_tag` (`site/_plugins/site.rb`) writes the file's hash from `config/frontend_integrity.json` as its `integrity` attribute, so the browser refuses a file that's changed since we chose it. After adding or bumping a CDN file, run `rake frontend:integrity`, which hashes each file that has no hash yet and drops those nothing loads any more. It keeps the hashes it has rather than trusting the CDN again, and refuses a version of an npm package released less than 7 days ago
- iframe-resizer stays on 4 (4.4.5 is MIT): 5 and later are GPL-3.0, or a paid licence

Ruby gems:

@Gemfile

Frontend dependencies:

@config/frontend_dependencies.rb
@config/frontend_package.json
