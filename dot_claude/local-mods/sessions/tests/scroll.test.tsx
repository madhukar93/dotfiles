import { describe, expect, test } from 'claude-code/testing'

// A model of how the engine moves the focus ring in the pane, taken from the built-in diff dialog:
// the ring is a SCREEN ROW. An arrow key moves it one row; the element at that row (as drawn now) is
// what the ui.focus hook hears; whatever element the hook lets through (or redirects to) is resolved
// against the tree drawn now, which fixes the row; after the redraw the ring is still on that row.
const IDS = Array.from({ length: 20 }, (_, i) => `s${String(i).padStart(2, '0')}-xxxxxxxx`)
const LIST = IDS.map((id, i) => JSON.stringify({ id, when: '11-24 01:00', title: `name-${i}`, recap: 'recap' })).join('\n')
const FOOTER = ['name', 'unname', 'focus-search']

const PANE = {
  plugin: 'sessions',
  component: 'Pane',
  requestId: 'sessions',
  surface: 'terminal',
  viewport: { columns: 160, rows: 30 },
  props: { title: 'Resume session', isFocused: true, bodyColumns: 150, placement: 'inline', scroll: { offset: 0, bodyRows: 30 }, view: {} },
} as const

describe('the session list as a window the arrow keys walk', () => {
  async function open($: any, on: any) {
    const state = new Map<string, { value: unknown; version: number }>()
    let slot = 0
    let drawn: string[] = []
    on('command.register', () => ({ value: { command: 'sessions' } }))
    on('ui.open', () => ({ value: { isPlaced: true } }))
    on('session.start', (_: unknown, e: { cwd: string }) => ({ cwd: e.cwd }))
    on('process.run', () => ({ value: { exitCode: 0, stdout: LIST, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
    on('state.get', (_: unknown, e: { plugin: string; key: string }) => ({ value: state.get(`${e.plugin}/${e.key}`) ?? { value: undefined, version: 0 } }))
    on('state.set', (_: unknown, e: { plugin: string; key: string; value: unknown }) => {
      const k = `${e.plugin}/${e.key}`
      const version = (state.get(k)?.version ?? 0) + 1
      state.set(k, { value: e.value, version })
      return { value: { isSet: true, version } }
    })
    const engine = (_: unknown, e: { element?: string; origin: { kind: string } }) => {
      const at = drawn.indexOf(String(e.element))
      if (at >= 0) slot = at // the ring stays on this row, whatever is drawn there after the redraw
      return e.origin.kind === 'plugin' ? { value: {} } : {}
    }
    on('ui.focus', { plugin: '*' }, engine)
    on('ui.focus', engine)
    await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
    await $.command.run({ command: 'sessions', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 160 } })
    const ui = await $.ui.mount(PANE)
    await ui.redraw()

    // the focusable elements as drawn now, top to bottom: the search box, then every button
    const tree = async () => {
      const buttons = (await ui.findAll({ type: 'Button' })) as { props?: { key?: string }; key?: string }[]
      return ['search', ...buttons.map(b => b.props?.key ?? b.key ?? '')]
    }
    const ringNow = async () => (await tree())[slot] ?? '?'
    async function press(dir: 1 | -1) {
      drawn = await tree()
      const target = drawn[slot + dir]
      if (target === undefined) return
      await $.ui.focus({ component: 'Pane', requestId: 'sessions', plugin: 'sessions', element: target, origin: { kind: 'person' } })
      await ui.redraw()
    }
    return { press, ringNow, tree }
  }

  test('down visits every session once, in order, and stops on the last without touching the footer', async ($, on) => {
    const { press, ringNow, tree } = await open($, on)
    const seen: string[] = []
    for (let i = 0; i < 40; i++) {
      await press(1)
      const here = await ringNow()
      expect(FOOTER, `press ${i + 1}: the ring is on the footer`).not.toContain(here)
      expect((await tree()).filter(k => IDS.includes(k)).length, 'drawn rows').toBeLessThanOrEqual(10)
      if (here !== 'search' && seen.at(-1) !== here) seen.push(here)
    }
    expect(seen).toEqual(IDS)
    expect(await ringNow()).toBe(IDS.at(-1))
  })

  test('up from the end visits every session in reverse, then reaches the search box', async ($, on) => {
    const { press, ringNow } = await open($, on)
    for (let i = 0; i < 40; i++) await press(1)
    const seen: string[] = [await ringNow()]
    for (let i = 0; i < 40; i++) {
      await press(-1)
      const here = await ringNow()
      if (seen.at(-1) !== here) seen.push(here)
    }
    expect(seen).toEqual([...IDS].reverse().concat('search'))
  })

  test('from the search box, down rests on the selected session, so the list does not jump', async ($, on) => {
    const { press, ringNow } = await open($, on)
    for (let i = 0; i < 12; i++) await press(1) // the 12th session is selected
    for (let i = 0; i < 40; i++) {
      await press(-1)
      if ((await ringNow()) === 'search') break
    }
    // back at the top the list re-centres on the first session; going down again starts from it
    await press(1)
    expect(await ringNow()).toBe(IDS[0])
  })
})
