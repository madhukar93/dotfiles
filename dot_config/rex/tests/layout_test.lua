-- Unit tests for ../layout.lua. Run: lua5.1 ~/.config/rex/tests/layout_test.lua
local dir = debug.getinfo(1, "S").source:match("^@(.*)/tests/") or "."
package.path = dir .. "/?.lua;" .. package.path
local layout = require("layout")

local function leaf(id) return { block_id = id } end
local function split(direction, before, after, ratio)
  return { split = { direction = direction, before = before, after = after, ratio = ratio or 0.5 } }
end
local function view(node) return { windows = { { layers = { { kind = "tiled", layout = node } } } } } end

local failures, count = 0, 0
local function check(name, got, want)
  count = count + 1
  local same = (got == nil and want == nil)
  if got and want then
    same = true
    for k, v in pairs(want) do if got[k] ~= v then same = false end end
    for k in pairs(got) do if want[k] == nil then same = false end end
  end
  if not same then
    failures = failures + 1
    local function show(t)
      if not t then return "nil" end
      local parts = {}
      for k, v in pairs(t) do parts[#parts + 1] = k .. "=" .. tostring(v) end
      table.sort(parts)
      return "{" .. table.concat(parts, ", ") .. "}"
    end
    print("FAIL " .. name .. "\n  got  " .. show(got) .. "\n  want " .. show(want))
  end
end

local side_by_side = view(split("horizontal", leaf("A"), leaf("B"), 0.3))

-- The bug fixed on 2026-11-23: the first (left) pane anchored to itself and nothing moved.
check("first pane of side-by-side moves before its neighbour, stacked",
  layout.plan_flip(side_by_side, "A"),
  { block_id = "A", anchor_block_id = "B", direction = "vertical", side = "before", ratio = 0.3 })

check("second pane of side-by-side moves after its neighbour, stacked",
  layout.plan_flip(side_by_side, "B"),
  { block_id = "B", anchor_block_id = "A", direction = "vertical", side = "after", ratio = 0.3 })

check("stacked panes go back to side by side",
  layout.plan_flip(view(split("vertical", leaf("A"), leaf("B"))), "A"),
  { block_id = "A", anchor_block_id = "B", direction = "horizontal", side = "before", ratio = 0.5 })

check("pane alone in its tab: nothing to do",
  layout.plan_flip(view(leaf("A")), "A"), nil)

check("neighbour is a group of panes: nothing to do",
  layout.plan_flip(view(split("horizontal", leaf("A"), split("vertical", leaf("B"), leaf("C")))), "A"), nil)

check("pane inside a nested split flips with its direct neighbour",
  layout.plan_flip(view(split("horizontal", leaf("A"), split("vertical", leaf("B"), leaf("C"), 0.6))), "C"),
  { block_id = "C", anchor_block_id = "B", direction = "horizontal", side = "after", ratio = 0.6 })

check("pane not in the view: nothing to do",
  layout.plan_flip(side_by_side, "Z"), nil)

check("no view (session.view failed): nothing to do",
  layout.plan_flip(nil, "A"), nil)

print(string.format("%d checks, %d failed", count, failures))
os.exit(failures == 0 and 0 or 1)
