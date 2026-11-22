// For our Sass (site/stylesheets/*.scss). No shared config: only rules that catch mistakes (a property, unit or selector
// that doesn't exist, a colour that isn't one, a declaration that overrides one just above it), not formatting. The
// compiled dark.css and light.css are Dart Sass's output, never edited, so they aren't linted
export default {
  customSyntax: 'postcss-scss',
  ignoreFiles: ['site/stylesheets/dark.css', 'site/stylesheets/light.css'],
  rules: {
    // Sass's flags too
    'annotation-no-unknown': [true, { ignoreAnnotations: ['default', 'global'] }],
    'block-no-empty': true,
    'color-no-invalid-hex': true,
    'declaration-block-no-duplicate-custom-properties': true,
    'declaration-block-no-duplicate-properties': [true, { ignore: ['consecutive-duplicates-with-different-syntaxes'] }],
    'declaration-block-no-shorthand-property-overrides': true,
    'function-calc-no-unspaced-operator': true,
    'keyframe-declaration-no-important': true,
    'media-feature-name-no-unknown': true,
    'no-duplicate-selectors': true,
    'no-invalid-double-slash-comments': true,
    'property-no-unknown': true,
    'selector-pseudo-class-no-unknown': true,
    'selector-pseudo-element-no-unknown': true,
    'selector-type-no-unknown': [true, { ignore: ['custom-elements'] }],
    'string-no-newline': true,
    'unit-no-unknown': true,
    // Bootstrap's colours, not ones of our own, where Bootstrap has one: a colour is one of its variables
    // ($primary, $body-color...) or our theme's. Not in a mask, where black and transparent say how much shows
    'color-named': ['never', {
      ignoreProperties: ['/^mask/'],
      message: 'Use a Bootstrap or theme variable ($danger, $contrast-color...), not a named colour'
    }]
  },
  overrides: [
    {
      // The themes define the variables: their colours are where colours come from
      files: ['site/stylesheets/dark.scss', 'site/stylesheets/light.scss', 'site/stylesheets/_settings.scss'],
      rules: { 'color-named': null }
    }
  ]
}
