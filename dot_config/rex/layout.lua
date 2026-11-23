-- Pure layout logic, kept free of rex.* calls so tests/layout_test.lua can run it with plain lua5.1.
local M = {}

-- Returns the split that directly holds block_id, and which side ("before" or "after") it is on.
local function find_parent(node, block_id)
  local s = node.split
  if not s then return nil end
  for _, side in ipairs({ "before", "after" }) do
    if s[side].block_id == block_id then return s, side end
    local found, found_side = find_parent(s[side], block_id)
    if found then return found, found_side end
  end
end

-- Given a session.view result, returns the session.move_block arguments (without session_id)
-- that turn block_id and its neighbour from side by side to stacked or back, or nil when
-- the block has no single-pane neighbour.
function M.plan_flip(view, block_id)
  for _, w in ipairs(view and view.windows or {}) do
    for _, layer in ipairs(w.layers or {}) do
      local split, side
      if layer.layout then split, side = find_parent(layer.layout, block_id) end
      if split then
        local other = split[side == "before" and "after" or "before"]
        if not other.block_id then return nil end -- neighbour is a group of panes
        return {
          block_id = block_id, anchor_block_id = other.block_id,
          direction = split.direction == "horizontal" and "vertical" or "horizontal",
          side = side, ratio = split.ratio,
        }
      end
    end
  end
end

return M
