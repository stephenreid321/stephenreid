module.exports = {
  env: {
    browser: true,
    es2021: true,
    jquery: true
  },
  globals: {
    chroma: true
  },
  extends: 'standard',
  overrides: [
  ],
  parserOptions: {
    ecmaVersion: 'latest'
  },
  rules: {
    camelcase: 'off',
    eqeqeq: 'off'
  }
}
