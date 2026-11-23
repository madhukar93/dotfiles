-- Unit tests for ../agents.lua. Run: lua5.1 ~/.config/rex/tests/agents_test.lua
local dir = debug.getinfo(1, "S").source:match("^@(.*)/tests/") or "."
package.path = dir .. "/?.lua;" .. package.path
local agents = require("agents")

local failures, count = 0, 0
local function check(name, got, want)
  count = count + 1
  if got ~= want then
    failures = failures + 1
    print("FAIL " .. name .. "\n  got  " .. tostring(got) .. "\n  want " .. tostring(want))
  end
end
local function id(p) return p and p.block_id end
local function pane(b, rank, at) return { block_id = b, rank = rank, updated_at = at } end

-- pane_state
local function rec(state, at) return { state = state, updated_at = at } end
check("working is not waiting", agents.pane_state({ records = { rec("working", "1") } }), nil)
check("idle is not waiting", agents.pane_state({ records = { rec("idle", "1") } }), nil)
check("no reply: not waiting", agents.pane_state(nil), nil)
check("done is waiting", agents.pane_state({ records = { rec("done", "1") } }).state, "done")
check("blocked beats a newer done",
  agents.pane_state({ records = { rec("blocked", "1"), rec("done", "2") } }).state, "blocked")
check("newest of equal states wins",
  agents.pane_state({ records = { rec("done", "1"), rec("done", "3") } }).updated_at, "3")

-- jump
local seen = {}
local panes = { pane("A", 3, "10"), pane("B", 1, "05"), pane("C", 3, "20") }
check("blocked pane comes first", id(agents.jump(panes, "X", seen)), "B")
check("then the newest done pane", id(agents.jump(panes, "B", seen)), "C")
check("then the older done pane", id(agents.jump(panes, "C", seen)), "A")
check("all seen: cycle to least recently visited", id(agents.jump(panes, "A", seen)), "B")

seen = {}
check("the pane you are in is never the target", id(agents.jump({ pane("A", 3, "1") }, "A", seen)), nil)
check("the pane you were in counts as seen: the older unseen pane goes first",
  id(agents.jump({ pane("A", 3, "1"), pane("B", 3, "0") }, "X", seen)), "B")

seen = {}
agents.jump({ pane("A", 3, "1"), pane("B", 3, "0") }, "X", seen) -- visits A
check("a pane whose state changed again is unseen again",
  id(agents.jump({ pane("A", 3, "2"), pane("B", 3, "0") }, "B", seen)), "A")

check("nothing waiting: no target", agents.jump({}, "A", {}), nil)

print(string.format("%d checks, %d failed", count, failures))
os.exit(failures == 0 and 0 or 1)
