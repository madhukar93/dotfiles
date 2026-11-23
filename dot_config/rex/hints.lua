-- Pure hint lookup for the "jump" key mode, kept free of rex.* calls so tests/hints_test.lua can run it.
local M = {}

-- matches come from bin/rex-hints, each with a hint. Returns the match whose hint is exactly typed,
-- "partial" when typed only starts some hints (two-letter hints), or nil when it fits none.
function M.resolve(matches, typed)
  local partial = false
  for _, m in ipairs(matches or {}) do
    if m.hint == typed then return m end
    if m.hint:sub(1, #typed) == typed then partial = true end
  end
  return partial and "partial" or nil
end

return M
