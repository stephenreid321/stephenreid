import js from '@eslint/js'
import globals from 'globals'

// Our files are classic scripts sharing the page's global scope, with libraries from the CDN
// (config/frontend_dependencies.rb)
export default [
  {
    ignores: ['node_modules/**', 'cloudflare/node_modules/**', 'vendor/**', 'site/fonts/**', '_site/**']
  },
  js.configs.recommended,
  {
    files: ['site/javascripts/**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'script',
      globals: {
        ...globals.browser,
        ...globals.jquery,
        Chart: 'readonly',
        Cookies: 'readonly'
      }
    },
    rules: {
      'no-empty': ['error', { allowEmptyCatch: true }]
    }
  },
  // The Cloudflare Worker that starts the scheduled workflows, an ES module
  {
    files: ['cloudflare/**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: globals.serviceworker
    }
  }
]
