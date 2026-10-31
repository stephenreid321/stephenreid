This is a static site built with Jekyll and served by GitHub Pages. There's no server and no database.

- `site/` is Jekyll's source: pages, `_layouts`, `_includes` (the markdown the pages show is in `_includes/markdown`), `_data` (YAML) and the assets, which are served at the root (`/images`, `/javascripts`, `/stylesheets`)
- `site/_plugins/site.rb` hands the templates their data, adds the `cdn_tag` and `cdn_dependencies` Liquid tags, and makes the pages that have no template of their own: the courses' notes, the `.txt` exports and the redirects (`REDIRECTS`, plus `/books/<slug>` to Goodreads)
- `lib/` is plain Ruby, loaded by `config/boot.rb` for the rake tasks and the plugin. Templates can't run Ruby, so work anything out there (as `lib/iconomi_pages.rb` does for the ICONOMI pages) and hand the template the result

`rake site:serve` serves the site at http://localhost:4000, rebuilding as files change; `rake site:build` builds it into `_site`.

## Data

- `data/*.csv` is the site's own data, committed: books, films, courses, speaking engagements, and what's been decided by hand about ICONOMI's strategies and assets (`iconomi_strategies.csv`: status; `iconomi_assets.csv`: status, multiplier, colour)
- `data/fetched/` is what the site shows from other sites, as JSON (`lib/fetched.rb`). It isn't committed: `rake data:fetch` fetches it (Substack and ICONOMI need their keys in the environment; `rake data:public` fetches what needs none), and the Site workflow keeps it between builds in the Actions cache. Except Substack's: its Cloudflare turns away GitHub's runners, so `substack_notes.json` and `substack_posts.json` are committed. To bring them up to date, run `rake data:substack` here and commit them
- Metastrategy's number of assets is the `NUMBER_OF_ASSETS` Actions variable

## Workflows

- `site.yml` builds the site and deploys it to Pages: on each push to master, from the last build's data, and every six hours (or by hand) with fresh data. Its job summary shows Metastrategy's proposals with and without multipliers, and what's unverified
- `tasks.yml` runs what Heroku's scheduler and the old admin page did: `rebalance` (Fridays, when the `ICONOMI_REBALANCE` variable is `true`), `verify` (marks strategies and assets with no status as verified and commits that) and `posts-sync` (daily)
- `ruby.yml` lints, and builds the site with what needs no keys

## Committing

Commit only the changes you made: stage your files by name rather than with `git add -A` or `git commit -a`.

`script/lint` runs our linters, RuboCop, ESLint and zizmor, each on the files of its kind. CI's lint job (`.github/workflows/ruby.yml`) runs it too, so it is the one place their commands and flags are set: change a linter's flags or add a linter there, not in the workflow. Run it on the files you added or changed, and fix what it reports:

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
- GitHub Actions are pinned to a commit of a release at least 7 days old, with the release as a comment (zizmor's `unpinned-uses`). zizmor's own version is in `script/lint`, and uv's in `.github/workflows/ruby.yml`
- The root `package.json` is only linters (ESLint, `eslint.config.mjs`). It installs from `package-lock.json` (`npm ci`): pin exact versions, and when adding or bumping one run `npm install --before=<the date a week ago>` so its own dependencies are a week old too
- The packages the site loads from jsDelivr have their versions in `config/frontend_package.json`, and only there: nothing installs them, `config/frontend_dependencies.rb` reads them. `FRONTEND_DEPENDENCIES` there lists the packages every page loads and their files; a page that needs one of its own loads it with `{% cdn_tag 'package', 'path/file.js' %}`. Load a file the package ships: jsDelivr minifies a `.min` file a package lacks on the fly, and that output can change
- `cdn_tag` (`site/_plugins/site.rb`) writes the file's hash from `config/frontend_integrity.json` as its `integrity` attribute, so the browser refuses a file that's changed since we chose it. After adding or bumping a CDN file, run `rake frontend:integrity`, which hashes each file that has no hash yet and drops those nothing loads any more. It keeps the hashes it has rather than trusting the CDN again, and refuses a version of an npm package released less than 7 days ago
- iframe-resizer stays on 4 (4.4.5 is MIT): 5 and later are GPL-3.0, or a paid licence

Ruby gems:

@Gemfile

Frontend dependencies:

@config/frontend_dependencies.rb
@config/frontend_package.json
