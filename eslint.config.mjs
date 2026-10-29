import js from '@eslint/js'
import globals from 'globals'

// Our files are classic scripts sharing the page's global scope, with libraries from the CDN
// (config/frontend_dependencies.rb)
export default [
  {
    ignores: ['node_modules/**', 'app/assets/fonts/**']
  },
  js.configs.recommended,
  {
    files: ['app/assets/javascripts/**/*.js'],
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
  }
]
