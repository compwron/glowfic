// INTENTIONALLY FAILING — demonstrates that the `javascript test suite` CI job
// goes red when a JS assertion fails (i.e. the framework actually gates merges,
// not just reports green). This file is NOT meant to be merged into main.
const { loadGlobals } = require('./support/sprockets');

const { queryTransform } = loadGlobals('app/assets/javascripts/global.js', ['queryTransform']);

describe('example: a deliberately failing test', () => {
  it('fails on purpose to prove CI catches JS test failures', () => {
    // queryTransform actually returns { q: 'x', page: 1 }; assert the wrong page
    // so Jest reports a real diff and the CI job exits non-zero.
    expect(queryTransform({ term: 'x', page: 1 })).toEqual({ q: 'x', page: 999 });
  });
});
