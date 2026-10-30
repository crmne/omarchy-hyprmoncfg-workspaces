const test = require('node:test')
const assert = require('node:assert/strict')
const Setup = require('../PanelSetup.js')

test('panel setup distinguishes absence, disabled state and old UI routes', () => {
  assert.equal(Setup.state('[]',0,''),'missing')
  const panel = {id:'crmne.hyprmoncfg',enabled:false}
  assert.equal(Setup.state(JSON.stringify([panel]),0,''),'disabled')
  panel.enabled=true
  assert.equal(Setup.state(JSON.stringify([panel]),0,''),'outdated')
  assert.equal(Setup.state(JSON.stringify([panel]),0,'unavailable'),'unavailable')
  for (const raw of ['', '{}', 'null', 'bad', ' '.repeat(1048577)])
    assert.equal(Setup.state(raw,0,''),'unknown')
  assert.equal(Setup.state('[]',1,''),'unknown')
})

test('failed discovery only offers retry, never an installation', () => {
  assert.equal(Setup.action('missing'),'install')
  assert.equal(Setup.action('disabled'),'enable')
  assert.equal(Setup.action('outdated'),'update')
  assert.equal(Setup.action('unavailable'),'open')
  assert.equal(Setup.action('unknown'),'retry')
})
