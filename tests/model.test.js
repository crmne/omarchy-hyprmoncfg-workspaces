const test = require('node:test')
const assert = require('node:assert/strict')
const m = require('../WorkspaceModel.js')

function monitor(name, x, y, id, extra = {}) {
  return { name, x, y, width: 1920, height: 1080, scale: 1, mirrorOf: 'none', activeWorkspace: { id }, ...extra }
}
function document(monitors, plans) {
  return { monitors: monitors.map(v => ({ ...v, key: v.name })), workspace_plan: plans.map(([name, ids]) => ({ output_name: name, output_key: name, workspaces: ids })) }
}

test('live location wins over assigned location without duplicate workspaces', () => {
  const monitors = [monitor('DP-2', 0, 0, 1), monitor('DP-1', 1920, 0, 4)]
  const doc = document(monitors, [['DP-2', ['1', '2', '3']], ['DP-1', ['4', '5', '6']]])
  const result = m.groups(doc, monitors, [{ id: 2, monitor: 'DP-1', windows: 2 }], 2)
  assert.deepEqual(result.map(g => g.workspaces.map(w => w.id)), [[1, 3], [2, 4, 5, 6]])
  assert.deepEqual(result[1].workspaces[0], { id: 2, occupied: true, urgent: false, focused: true, visible: false })
  assert.equal(result[1].workspaces[1].visible, true)
  assert.deepEqual(result.map(g => g.focused), [false, true])
})

test('stacked three-monitor geometry is preserved independently of workspace numbering', () => {
  const monitors = [monitor('right', 1920, 0, 4), monitor('above', 0, -1080, 7), monitor('left', 0, 0, 1)]
  const screens = m.liveScreens(monitors)
  assert.deepEqual(screens.map(s => s.name), ['above', 'left', 'right'])
  const rects = m.rectangles(screens, 600, 400, 0)
  assert.equal(rects[0].x, rects[1].x)
  assert.equal(rects[0].y + rects[0].height, rects[1].y)
  assert.equal(rects[1].x + rects[1].width, rects[2].x)
})

test('scale, rotation and negative coordinates produce logical rectangles', () => {
  const [s] = m.liveScreens([monitor('portrait', -1080, -200, 1, { width: 3840, height: 2160, scale: 2, transform: 1 })])
  assert.equal(s.width, 1080)
  assert.equal(s.height, 1920)
  const [rect] = m.rectangles([s], 100, 100, 0)
  assert.equal(rect.height, 100)
  assert.ok(rect.x > 0)
  assert.equal(rect.y, 0)
})

test('unplug and mirror do not manufacture extra destinations or relocate existing ones', () => {
  const monitors = [monitor('main', 0, 0, 1), monitor('mirror', 0, 0, 1, { mirrorOf: 'main' }), monitor('off', 0, 0, 9, { disabled: true })]
  const doc = document(monitors, [['main', ['1', '2']], ['off', ['9']]])
  const result = m.groups(doc, monitors, [{ id: 2, monitor: 'removed' }], 1)
  assert.deepEqual(result.map(g => g.name), ['main'])
  assert.deepEqual(result[0].workspaces.map(w => w.id), [1])
})

test('a reused connector does not inherit another display plan', () => {
  const old = monitor('DP-1', 0, 0, 4, { serial: 'old' })
  const replacement = { ...old, serial: 'new', activeWorkspace: { id: 8 } }
  const result = m.groups(document([old], [['DP-1', ['4', '5']]]), [replacement], [], 8)
  assert.deepEqual(result[0].workspaces.map(w => w.id), [8])
})

test('older or absent daemons leave live workspaces usable', () => {
  const monitors = [monitor('DP-1', 0, 0, 12)]
  for (const doc of [{}, null, { monitors: [] }]) {
    const result = m.groups(doc, monitors, [{ id: 12, monitor: 'DP-1', windows: 1 }, { id: -99, name: 'special:x', monitor: 'DP-1' }], 12)
    assert.deepEqual(result[0].workspaces.map(w => w.id), [12])
  }
})

test('navigation stays within a group and preserves actual IDs above ten', () => {
  const groups = [{ name: 'left', workspaces: [{ id: 1 }, { id: 3 }] }, { name: 'right', workspaces: [{ id: 12 }, { id: 16 }] }]
  assert.equal(m.neighbour(groups, 3, 1, 'left'), 3)
  assert.equal(m.neighbour(groups, 3, 1, ''), 12)
  assert.equal(m.neighbour(groups, 3, 1, 'right'), 12)
  assert.equal(m.focusRequest(12, true), 'hl.dsp.focus({ workspace = "12" })')
  assert.equal(m.focusRequest(12, false), 'workspace 12')
})

test('unsafe IDs and markup cannot reach commands or tooltip markup', () => {
  for (const id of ['1; exec bad', '2"', -1, 0, null, 2147483648]) assert.equal(m.focusRequest(id, true), '')
  assert.equal(m.plain('<img src=x>\u0000DP-1'), 'img src=xDP-1')
  assert.ok(m.plain('x'.repeat(1000)).length <= 160)
})

test('scrolling an unfocused monitor starts at its visible workspace', () => {
  const groups = [{ name: 'right', visibleId: 5, workspaces: [{id:4}, {id:5}, {id:6}] }]
  assert.equal(m.neighbour(groups, 1, 1, 'right'), 6)
  assert.equal(m.neighbour(groups, 1, -1, 'right'), 4)
})
