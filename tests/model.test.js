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
  assert.deepEqual(result[1].workspaces[0], { id: 2, label: '2', occupied: true, urgent: false, focused: true, visible: false })
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


test('per display strategy labels each workspace by its slot and keeps real IDs', () => {
  const monitors = [monitor('left', 0, 0, 1), monitor('right', 1920, 0, 13)]
  const doc = { ...document(monitors, [['left', ['1', '2', '10']], ['right', ['11', '12', '13', '20']]]),
    per_display_workspaces: { block_size: 10, slots: 10 } }
  const result = m.groups(doc, monitors, [], 13)
  assert.deepEqual(result.map(g => g.workspaces.map(w => w.id)), [[1, 2, 10], [11, 12, 13, 20]])
  assert.deepEqual(result.map(g => g.workspaces.map(w => w.label)), [['1', '2', '0'], ['1', '2', '3', '0']])
  assert.equal(m.focusRequest(result[1].workspaces[2].id, false), 'workspace 13')
})

test('without per display workspaces, labels stay global numbers', () => {
  const monitors = [monitor('left', 0, 0, 1), monitor('right', 1920, 0, 12)]
  const plans = [['left', ['1', '10']], ['right', ['11', '12']]]
  for (const extra of [{}, { per_display_workspaces: null }, { per_display_workspaces: { block_size: 0, slots: 3 } },
    { per_display_workspaces: { block_size: '10; x', slots: 3 } }, { per_display_workspaces: { block_size: 10, slots: 11 } },
    { per_display_workspaces: { block_size: 10 } }]) {
    const result = m.groups({ ...document(monitors, plans), ...extra }, monitors, [], 1)
    assert.deepEqual(result.map(g => g.workspaces.map(w => w.label)), [['1', '10'], ['11', '12']])
  }
  assert.equal(m.workspaceLabel(25, null), '25')
  assert.equal(m.workspaceLabel(25, 10), '5')
  assert.equal(m.workspaceLabel(30, 10), '0')
  assert.equal(m.perDisplayBlock({ per_display_workspaces: { block_size: 10, slots: 4 } }), 10)
})

const perDisplayDoc = (extra = {}) => ({ per_display_workspaces: { block_size: 10, slots: 10, ...extra } })
const ws = (id, monitor, windows = 0) => ({ id, monitor: { name: monitor }, toplevels: { values: new Array(windows).fill({}) } })

test('per display config is read from the daemon and malformed blocks are dropped', () => {
  const config = m.perDisplay(perDisplayDoc({ delegate: 'omarchy', blocks: [
    { output_name: 'DP-1', block: 1 }, { output_name: 'eDP-1', block: 0 }, { output_name: '', block: 2 },
    { output_name: 'HDMI-A-1', block: -1 }, { output_name: 'DP-2', block: 1.5 }, null] }))
  assert.deepEqual(config, { blockSize: 10, slots: 10, delegate: 'omarchy', blocks: { 'DP-1': 1, 'eDP-1': 0 } })
  assert.equal(m.perDisplay(perDisplayDoc({ delegate: 'other' })).delegate, '')
  assert.deepEqual(m.perDisplay(perDisplayDoc()).blocks, {})
  for (const doc of [{}, null, { per_display_workspaces: { block_size: 10, slots: 0 } }]) assert.equal(m.perDisplay(doc), null)
})

test('a display uses its block from the daemon, else the block of the workspace it shows', () => {
  const config = m.perDisplay(perDisplayDoc({ blocks: [{ output_name: 'DP-1', block: 2 }] }))
  assert.equal(m.displayBlock(config, 'DP-1', 3), 2)
  assert.equal(m.displayBlock(config, 'HDMI-A-1', 14), 1)
  assert.equal(m.displayBlock(config, 'HDMI-A-1', 20), 1)
  assert.equal(m.displayBlock(config, 'HDMI-A-1', -1), 0)
})

test('a display shows the first five of its block, its existing workspaces, then guests', () => {
  const config = m.perDisplay(perDisplayDoc({ blocks: [{ output_name: 'DP-1', block: 1 }] }))
  const live = [ws(19, 'DP-1', 1), ws(3, 'DP-1'), ws(1, 'eDP-1'), ws(12, 'eDP-1'), ws(25, 'DP-1'), ws(-98, 'DP-1')]
  assert.deepEqual(m.displayWorkspaceIds(config, 1, 'DP-1', live), [11, 12, 13, 14, 15, 19, 3, 25])
  const entries = m.displayEntries(config, 'DP-1', 19, live, 19)
  assert.deepEqual(entries.map(e => e.label), ['1', '2', '3', '4', '5', '9', '3', '5'])
  assert.deepEqual(entries.map(e => e.firstGuest), [false, false, false, false, false, false, true, false])
  assert.deepEqual(entries[5], { id: 19, slot: 9, label: '9', guest: false, firstGuest: false, occupied: true, urgent: false, visible: true, focused: true })
  assert.equal(m.displayEntries(config, 'DP-1', 20, [ws(20, 'DP-1')], 1).at(-1).label, '0')
})

test('a display never shows more empty slots than it has', () => {
  const config = m.perDisplay(perDisplayDoc({ slots: 3 }))
  assert.deepEqual(m.displayWorkspaceIds(config, 0, 'DP-1', []), [1, 2, 3])
  assert.deepEqual(m.displayWorkspaceIds(config, 2, 'DP-1', [ws(27, 'DP-1')]), [21, 22, 23, 27])
})

test('per display clicks go through Omarchy only when it runs the workspaces', () => {
  const delegated = m.perDisplay(perDisplayDoc({ delegate: 'omarchy' }))
  const own = m.perDisplay(perDisplayDoc())
  assert.equal(m.displayFocusRequest(delegated, 1, 'DP-1', 13, true), 'o.workspaces.focus(3, "DP-1")')
  assert.equal(m.displayFocusRequest(delegated, 1, 'DP-1', 4, true), 'hl.dsp.focus({ workspace = "4" })')
  assert.equal(m.displayFocusRequest(delegated, 1, 'DP-1"); x("', 13, true), 'hl.dsp.focus({ workspace = "13" })')
  assert.equal(m.displayFocusRequest(own, 1, 'DP-1', 13, true), 'hl.dsp.focus({ workspace = "13" })')
  assert.equal(m.displayFocusRequest(own, 1, 'DP-1', 13, false), 'workspace 13')
  assert.equal(m.displayFocusRequest(own, 1, 'DP-1', '13; bad', false), '')
})

test('per display scrolling moves along the row and holds at its ends', () => {
  const ids = [11, 12, 13, 19, 3]
  assert.equal(m.displayScrollTarget(ids, 12, -1), 13)
  assert.equal(m.displayScrollTarget(ids, 12, 1), 11)
  assert.equal(m.displayScrollTarget(ids, 11, 1), null)
  assert.equal(m.displayScrollTarget(ids, 3, -2), null)
  assert.equal(m.displayScrollTarget(ids, 99, 1), null)
})
