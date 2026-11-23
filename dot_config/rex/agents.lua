-- Pure logic for "jump to the next waiting agent", kept free of rex.* calls so
-- tests/agents_test.lua can run it with plain lua5.1.
local M = {}

-- States in which an agent waits for you. Lower rank is visited first.
local RANK = { blocked = 1, error = 2, done = 3 }

-- Reduces a program_status reply to the pane's most urgent waiting record:
-- { rank, state, updated_at }, or nil when no program in the pane is waiting.
function M.pane_state(reply)
  local best
  for _, r in ipairs(reply and reply.records or {}) do
    local rank = RANK[r.state]
    local at = r.updated_at or ""
    if rank and (not best or rank < best.rank or (rank == best.rank and at > best.updated_at)) then
      best = { rank = rank, state = r.state, updated_at = at }
    end
  end
  return best
end

local visits = 0
local function mark(seen, pane)
  visits = visits + 1
  seen[pane.block_id] = { updated_at = pane.updated_at, n = visits }
end

-- panes: waiting panes as { block_id, rank, updated_at, ... }.
-- seen: block_id -> { updated_at, n }, kept by the caller between calls.
-- Marks the pane you are in as seen, then returns the pane to jump to (and marks it), or nil.
-- A pane counts as seen until its state changes again (a new updated_at).
-- Order: panes not yet seen, most urgent then newest first; when all were seen,
-- cycle through them, least recently visited first.
function M.jump(panes, current_block_id, seen)
  local unseen, visited = {}, {}
  for _, p in ipairs(panes) do
    if p.block_id == current_block_id then
      mark(seen, p)
    else
      local s = seen[p.block_id]
      if s and s.updated_at == p.updated_at then visited[#visited + 1] = p else unseen[#unseen + 1] = p end
    end
  end
  table.sort(unseen, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.updated_at > b.updated_at
  end)
  table.sort(visited, function(a, b) return seen[a.block_id].n < seen[b.block_id].n end)
  local target = unseen[1] or visited[1]
  if target then mark(seen, target) end
  return target
end

return M
