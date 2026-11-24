import { atom, read, update } from 'claude-code'
import type { Hook, Register } from 'claude-code'

import type { Proposal, Session } from '../types'

const PANE = 'sessions'
// shortcut: assumes the engine's process runs in the project folder and Claude Code names project folders by replacing '/' with '-'; upgrade if a project path contains other special characters
const DIR = '~/.claude/projects/' // the python scripts append the working folder's name
const sessions = atom({ plugin: 'sessions', key: 'sessions' } as const, [], {
  shape: 'sessions-1',
})
const proposals = atom({ plugin: 'sessions', key: 'proposals' } as const, [], {
  shape: 'proposals-1',
})
const status = atom({ plugin: 'sessions', key: 'status' } as const, '', {
  shape: 'status-1',
})
const query = atom({ plugin: 'sessions', key: 'query' } as const, '', {
  shape: 'query-1',
})
// The session the list is centred on, and the element the focus ring is on ('search' or a session id).
const selected = atom({ plugin: 'sessions', key: 'selected' } as const, '', {
  shape: 'selected-1',
})
const ring = atom({ plugin: 'sessions', key: 'ring' } as const, 'search', {
  shape: 'ring-1',
})

// The list is a window of `windowRows` one-line rows centred on the selected session, as the built-in diff
// dialog does it. The engine keeps the focus ring by screen row, not by key, so when the ring moves
// the window re-centres and the ring is sent to the row that will hold the selection after the redraw.
// Rows of sessions drawn at once: set from the terminal's height each time the pane draws, read by the focus
// hook. shortcut: a module variable, so a hot reload resets it to 10 until the next draw.
let windowRows = 10
function startOf(length: number, at: number): number {
  return Math.max(0, Math.min(length - windowRows, Math.max(0, at) - Math.floor(windowRows / 2)))
}

// Every space-separated word must appear in order (as a subsequence) in the date, name or recap.
// Rows with a literal substring match rank first; ties keep newest first.
function inOrder(word: string, text: string): boolean {
  let at = 0
  for (const ch of text) if (ch === word[at] && ++at === word.length) return true
  return word.length === 0
}

function search(list: Session[], q: string): Session[] {
  const words = q.toLowerCase().split(/\s+/).filter(Boolean)
  if (words.length === 0) return list
  const hay = (s: Session) => `${s.when} ${s.title} ${s.recap}`.toLowerCase()
  const hits = list.filter(s => words.every(w => inOrder(w, hay(s))))
  const exact = (s: Session) => (words.every(w => hay(s).includes(w)) ? 0 : 1)
  return hits.map((s, i) => [s, i] as const).sort((a, b) => exact(a[0]) - exact(b[0]) || a[1] - b[1]).map(x => x[0])
}

// shortcut: Python scans whole logs (some >4 MB, over $.fs.read's cap); fine for ~20 sessions.
const SCRIPT = `
import sys, os, json, glob, datetime
PROJ = os.path.expanduser(sys.argv[1]) + os.getcwd().replace('/', '-')
for f in sorted(glob.glob(PROJ + '/*.jsonl'), key=os.path.getmtime, reverse=True)[:40]:
    recap = ''; title = ''
    for line in open(f, errors='replace'):
        if '"subtype":"away_summary"' in line:
            try: recap = json.loads(line)['content'].replace(' (disable recaps in /config)', '')
            except Exception: pass
        elif '"type":"custom-title"' in line:
            try: title = json.loads(line)['customTitle']
            except Exception: pass
    sid = os.path.basename(f)[:-6]
    when = datetime.datetime.fromtimestamp(os.path.getmtime(f)).strftime('%m-%d %H:%M')
    print(json.dumps({'id': sid, 'when': when, 'title': title or sid[:8], 'recap': recap or '(no recap yet)'}))
`

// Sessions with a recap but no name set by the person (/rename or a title line).
const UNNAMED = `
import sys, os, json, glob, time
PROJ = os.path.expanduser(sys.argv[1]) + os.getcwd().replace('/', '-')
for f in sorted(glob.glob(PROJ + '/*.jsonl'), key=os.path.getmtime, reverse=True):
    recap = ''; named = False
    for line in open(f, errors='replace'):
        if '"type":"custom-title"' in line: named = True; break
        if '"subtype":"away_summary"' in line:
            try: recap = json.loads(line)['content'].replace(' (disable recaps in /config)', '')
            except Exception: pass
    if recap and not named: print(json.dumps({'id': os.path.basename(f)[:-6], 'recap': recap}))
`

// Appends the same title line /rename writes; logs each append so UNDO can remove exactly it.
const APPLY = `
import sys, os, json, time
PROJ = os.path.expanduser(sys.argv[1]) + os.getcwd().replace('/', '-')
d, logf = PROJ, os.path.expanduser(sys.argv[2])
os.makedirs(os.path.dirname(logf), exist_ok=True)
for p in json.loads(sys.argv[3]):
    f = os.path.join(d, p['id'] + '.jsonl')
    if any('"type":"custom-title"' in l for l in open(f, errors='replace')): print('skipped (named): ' + p['id'][:8]); continue
    add = json.dumps({'type': 'custom-title', 'customTitle': p['name'], 'sessionId': p['id']}, separators=(',', ':')) + '\\n'
    st = os.stat(f)
    with open(f, 'rb') as fh:
        fh.seek(0, 2)
        if fh.tell() and (fh.seek(-1, 2) or fh.read(1)) != b'\\n': add = '\\n' + add
    with open(f, 'ab') as fh:  # append mode: a session still writing its own log cannot be overwritten
        fh.write(add.encode())
    os.utime(f, ns=(st.st_atime_ns, st.st_mtime_ns))  # keep the real last-activity time
    open(logf, 'a').write(json.dumps({'id': p['id'], 'added': add}) + '\\n')
    print('named ' + p['id'][:8] + ' -> ' + p['name'])
`

const UNDO = `
import sys, os, json
PROJ = os.path.expanduser(sys.argv[1]) + os.getcwd().replace('/', '-')
d, logf = PROJ, os.path.expanduser(sys.argv[2])
if not os.path.exists(logf): print('nothing to undo'); sys.exit()
for l in open(logf):
    r = json.loads(l); f = os.path.join(d, r['id'] + '.jsonl'); add = r['added'].encode()
    data = open(f, 'rb').read()
    if data.endswith(add):
        open(f, 'wb').write(data[:-len(add)]); print('removed name from ' + r['id'][:8])
    else: print('left alone (log changed since): ' + r['id'][:8])
os.rename(logf, logf + '.undone')
`
const NAMES_LOG = '~/.claude/sessions-plugin-names.jsonl'

type Ctx = Parameters<Hook<'command.run'>>[0]

// All of /sessions lives here, not in the hook: a plugin's own $.command.run skips its own
// command.run hooks, so the pane's buttons call this function directly.
async function sessionsCommand($: Ctx, args: string): Promise<{ text: string }> {
  try {
    // A plain function, not a nested /sessions run: a command run from inside its own hook skips that hook.
    const applyAll = async (): Promise<string> => {
      const todo = await read($, proposals)
      if (todo.length === 0) return 'No proposed names. Run "/sessions name" first.'
      const { stdout } = await $.process.run(
        ['python3', '-I', '-c', APPLY, DIR, NAMES_LOG, JSON.stringify(todo.map(t => ({ id: t.id, name: t.name })))],
        { timeoutMs: 30000 },
      )
      await update($, proposals, () => [])
      return stdout.trim() + '\n\nUndo with "/sessions name undo".'
    }
    if (args === 'name' || args === 'name auto') {
      const { stdout } = await $.process.run(['python3', '-I', '-c', UNNAMED, DIR], { timeoutMs: 20000 })
      const found: { id: string; recap: string }[] = stdout.trim().split('\n').filter(Boolean).map(l => JSON.parse(l))
      const made: Proposal[] = []
      for (const f of found) {
        const r = await $.model.complete({
          model: 'haiku',
          maxTokens: 30,
          effort: 'low',
          prompt: 'Write a 2 to 4 word lowercase name joined with hyphens (like go-concurrency-lessons) for a work session with this recap. Reply with the name only.\n\n' + f.recap,
        })
        const name = r.isAnswered ? r.text.toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) : ''
        if (name) made.push({ id: f.id, name, recap: f.recap })
      }
      await update($, proposals, () => made)
      if (args === 'name auto' && made.length > 0) {
        return { text: await applyAll() }
      }
      return {
        text: made.length === 0
          ? 'No unnamed sessions with a recap found.'
          : 'Proposed names (nothing written yet):\n' + made.map(m => `  ${m.id.slice(0, 8)}  ${m.name}`).join('\n') + '\n\nRun "/sessions name apply" to save them, or "/sessions name" again to redo.',
      }
    }
    if (args === 'name apply') return { text: await applyAll() }
    if (args === 'name undo') {
      const { stdout } = await $.process.run(['python3', '-I', '-c', UNDO, DIR, NAMES_LOG], { timeoutMs: 30000 })
      return { text: stdout.trim() }
    }
    try {
      const { stdout } = await $.process.run(['python3', '-I', '-c', SCRIPT, DIR], { timeoutMs: 20000 })
      const list: Session[] = stdout.trim().split('\n').filter(Boolean).map(l => JSON.parse(l))
      await update($, sessions, () => list)
      await update($, query, () => '')
      await update($, status, () => '')
      await update($, ring, () => 'search')
      await update($, selected, () => '')
      await $.ui.open({ id: PANE, title: 'Resume session', focus: true, closeOnEscape: true, holdToasts: true, rows: 80 })
      return { text: 'Pick a session (arrows + Enter, Esc to close).' }
    } catch (err) {
      return { text: 'sessions failed: ' + String(err) }
    }
    } catch (err) {
      return { text: 'sessions error: ' + String(err) }
    }
}

// Footer buttons exist for their hotkeys only; the arrow keys never rest the ring on them.
const FOOTER_KEYS = ['name', 'unname', 'focus-search']

const visible = (all: Session[], q: string) => (q.trim().startsWith(':') ? all : search(all, q))

export const register: Register = on => {
  on('ui.focus', { requestId: PANE }, async ($, e, next) => {
    const element = e.element
    if (!element) return next(e)
    if (e.origin.kind === 'person' && FOOTER_KEYS.includes(element)) {
      return { deny: 'footer buttons are hotkey-only' }
    }
    const hits = visible(await read($, sessions), await read($, query))
    const picked = hits.findIndex(h => h.id === element)
    const previous = await read($, ring)
    if (picked < 0 || e.origin.kind !== 'person') {
      // the search box, or a move the mod made itself: just note where the ring is
      const landed = await next(e)
      await update($, ring, () => element)
      return landed
    }
    const chosen = await read($, selected)
    const chosenAt = hits.findIndex(h => h.id === chosen)
    const before = startOf(hits.length, chosenAt)
    if (previous === 'search' || previous === '') {
      // arriving from the search box: rest on the selected row (or the first one drawn), window unchanged
      const rest = hits[chosenAt >= 0 ? chosenAt : before]
      if (!rest) return next(e)
      const landed = await next({ ...e, element: rest.id })
      await update($, selected, () => rest.id)
      await update($, ring, () => rest.id)
      return landed
    }
    // a step from one row to another: select it, centre the window on it, and send the ring to the row
    // (as drawn now) that will sit where the selection does after the redraw
    const landing = hits[before + picked - startOf(hits.length, picked)]
    if (!landing) return next(e)
    const landed = await next({ ...e, element: landing.id })
    await update($, selected, () => hits[picked]!.id)
    await update($, ring, () => hits[picked]!.id)
    return landed
  })

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'sessions',
      description: 'Pick a past session to resume, with each latest recap shown',
    })
    return next(e)
  })

  // /sessions shows our list; choosing one runs the untouched built-in /resume <id>.
  on('command.run', { command: 'sessions' }, ($, e) => sessionsCommand($, e.args.trim()))

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button, Input } = $.ui.resolve(e)
    const q = await read($, query)
    const note = await read($, status)
    const all = await read($, sessions)
    const hits = visible(all, q)
    const chosen = await read($, selected)
    const onRing = await read($, ring)
    // the pane fills the terminal: all rows but those taken by the header, search box, notes, footer and prompt
    windowRows = Math.max(6, Math.min(40, (e.viewport?.rows ?? 30) - 20))
    const chosenAt = hits.findIndex(h => h.id === chosen)
    const first = startOf(hits.length, chosenAt)
    const shown = hits.slice(first, first + windowRows)
    const columns = (e.props as { bodyColumns?: number }).bodyColumns ?? 100
    const oneLine = (t: string, width: number) => {
      const one = t.replace(/\s+/g, ' ')
      return one.length > width ? one.slice(0, Math.max(0, width - 1)) + '…' : one
    }
    const resume = async (id: string) => {
      await $.ui.close({ id: PANE })
      await $.command.run({ command: 'resume', args: id })
    }
    const run = async (args: string, busy: string) => {
      await update($, status, () => busy)
      const r = await sessionsCommand($, args)
      await update($, status, () => r.text)
    }
    // Typed into the search box, then Enter: ":name" names sessions, ":undo" undoes it; anything else resumes the top match.
    const submit = (v: string) => {
      const word = v.trim().toLowerCase()
      if (word.startsWith(':')) {
        void update($, query, () => '')
        if (word === ':name') return void run('name auto', 'Naming unnamed sessions…')
        if (word === ':undo') return void run('name undo', 'Undoing…')
        return void update($, status, () => 'Unknown command. Use :name or :undo.')
      }
      if (hits[0]) return void resume(hits[0].id)
    }

    return (
      <Box flexDirection="column" paddingX={1}>
        <Box>
          <Text bold color="claude">Resume a session</Text>
          <Text dimColor>  {hits.length === all.length ? `${all.length} recent` : `${hits.length} of ${all.length}`}</Text>
        </Box>
        <Box marginTop={1} marginBottom={1}>
          <Input
            key="search"
            label="search "
            placeholder="filter sessions · :name · :undo"
            value={q}
            autoFocus={onRing === 'search' ? true : undefined}
            submitLabel={q.trim().startsWith(':') ? 'run' : 'resume top match'}
            onInput={v => {
              void update($, query, () => v)
              void update($, selected, () => '')
            }}
            onSubmit={submit}
          />
        </Box>
        {hits.length === 0 && <Text dimColor>No session matches.</Text>}
        <Text dimColor>{first > 0 ? `  ↑ ${first} more` : ' '}</Text>
        {shown.map(s => (
          <Button key={s.id} plain onPress={() => void resume(s.id)}>
            <Text bold>{(s.id === chosen ? '❯ ' : '  ') + s.title}</Text>
            <Text dimColor>{'  ' + s.when + '  ' + oneLine(s.recap, columns - s.title.length - s.when.length - 8)}</Text>
          </Button>
        ))}
        <Text dimColor>{first + shown.length < hits.length ? `  ↓ ${hits.length - first - shown.length} more` : ' '}</Text>
        {note !== '' && (
          <Box marginBottom={1}>
            <Text color="success">{note}</Text>
          </Box>
        )}
        <Box gap={2}>
          <Button key="name" plain hotkey="n" onPress={() => void run('name auto', 'Naming unnamed sessions…')}>
            name unnamed
          </Button>
          <Button key="unname" plain hotkey="u" onPress={() => void run('name undo', 'Undoing…')}>
            undo naming
          </Button>
          <Button key="focus-search" plain hotkey="s" onPress={() => void $.ui.focus({ requestId: PANE, key: 'search' })}>
            search
          </Button>
        </Box>
        <Text dimColor>{'↓/↑ move · Enter resume · Esc close · n name, u undo, s search · in search: :name :undo'}</Text>
      </Box>
    )
  })
}
