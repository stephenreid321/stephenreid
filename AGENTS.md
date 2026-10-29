This is a Ruby/Mongo app based on the Padrino framework, which is in turn based on Sinatra. (It is NOT a Rails app.)

The ORM is Mongoid, not ActiveRecord.

## Files in lib

Files in lib are auto-loaded by Padrino.load!. No explicit require is necessary.

## Mongo

We set `Mongoid.raise_not_found_error = false` in `boot.rb` so Model.find(id) returns nil for invalid ids.

## Committing

Commit only the changes you made: stage your files by name rather than with `git add -A` or `git commit -a`.

`script/lint` runs our linters, RuboCop, erb_lint, ESLint and zizmor, each on the files of its kind. CI's lint job (`.github/workflows/ruby.yml`) runs it too, so it is the one place their commands and flags are set: change a linter's flags or add a linter there, not in the workflow. Run it on the files you added or changed, and fix what it reports:

```bash
script/lint <files>
```

If a linter's config is among them (`.rubocop.yml`, `.erb_lint.yml`, `eslint.config.mjs`, `package.json`), it runs that linter on everything, as CI does; `script/lint --all` runs them all, and `--only <linter>` just one. Run `npm ci` first if `node_modules` is missing, and install uv (https://docs.astral.sh/uv/) if `uvx` is.

The pre-commit hook (`.githooks/pre-commit`) runs `script/lint --staged`, which lints the staged version of each staged file. Git runs it once `core.hooksPath` is `.githooks`: run `git config core.hooksPath .githooks` once in each checkout. Never skip it with `--no-verify`.

Templates are checked for Lint and Security cops only (`.erb_lint.yml`), not style: don't run `erb_lint --autocorrect`, which deletes a bare `<%` on a template's first line.

## Stylesheets

The site has two themes, `dark` and `light` (`?stylesheet=light`), each `app/assets/stylesheets/<theme>.scss`: the theme's Bootstrap variables, then `_settings.scss` (variables both share), Bootstrap, and `_core.scss` (styles both share). Style with Bootstrap variables where one exists, rather than overriding its classes. Never edit the compiled `dark.css` and `light.css`: change the Sass and run `rake stylesheets:build` (needs Node), which compiles both with Dart Sass and Bootstrap at the version in `frontend/package.json`, so the CSS and Bootstrap's JavaScript always match. Commit the compiled CSS with its source.

Markup uses Bootstrap 5: `data-bs-*` attributes, `ms-*`/`me-*`, `text-start`/`text-end`, `text-bg-*` badges and `visually-hidden`.

## Dependencies

Cooldown: never use a gem or JS package version released less than 7 days ago. This guards against supply-chain attacks on freshly published versions. If a version that was just released can't be found, that's why: wait until it's a week old rather than removing or shortening the cooldown.

- `rake stylesheets:build` installs Bootstrap and Dart Sass with `npm install --before` set to 7 days ago, and pins Dart Sass's version
- Gems: the Gemfile's source has `cooldown: 7`, so Bundler (4 or later) enforces it
- GitHub Actions are pinned to a commit of a release at least 7 days old, with the release as a comment (zizmor's `unpinned-uses`). zizmor's own version is in `script/lint`, and uv's in `.github/workflows/ruby.yml`
- The root `package.json` is only linters (ESLint, `eslint.config.mjs`). It installs from `package-lock.json` (`npm ci`): pin exact versions, and when adding or bumping one run `npm install --before=<the date a week ago>` so its own dependencies are a week old too
- The packages the site loads from jsDelivr have their versions in `frontend/package.json`, and only there: nothing installs them, `config/frontend_dependencies.rb` reads them. `FRONTEND_DEPENDENCIES` there lists the packages every page loads and their files; a page that needs one of its own loads it with `<%= cdn_tag 'package', 'path/file.js' %>`. Load a file the package ships: jsDelivr minifies a `.min` file a package lacks on the fly, and that output can change
- `cdn_tag` writes the file's hash from `frontend/integrity.json` as its `integrity` attribute, so the browser refuses a file that's changed since we chose it. After adding or bumping a CDN file, run `rake frontend:integrity`, which hashes each file that has no hash yet and drops those nothing loads any more. It keeps the hashes it has rather than trusting the CDN again, and refuses a version of an npm package released less than 7 days ago
- iframe-resizer stays on 4 (4.4.5 is MIT): 5 and later are GPL-3.0, or a paid licence

Ruby gems:

@Gemfile

Frontend dependencies:

@config/frontend_dependencies.rb
@frontend/package.json
