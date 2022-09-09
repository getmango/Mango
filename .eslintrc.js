module.exports = {
  parser: '@babel/eslint-parser',
  parserOptions: { requireConfigFile: false },
  plugins: ['prettier'],
  rules: {
    eqeqeq: ['error', 'always'],
    'object-shorthand': ['error', 'always'],
    'prettier/prettier': 'error',
    'no-var': 'error',
  },
};
