-- Unit tests for ../hints.lua. Run: lua5.1 ~/.config/rex/tests/hints_test.lua
local dir = debug.getinfo(1, "S").source:match("^@(.*)/tests/") or "."
package.path = dir .. "/?.lua;" .. package.path
local hints = require("hints")

local failures, count = 0, 0
local function check(name, got, want)
  count = count + 1
  if got ~= want then
    failures = failures + 1
    print("FAIL " .. name .. ": got " .. tostring(got) .. ", want " .. tostring(want))
  end
end

local one = { { hint = "a", row = 3, col = 7 }, { hint = "s", row = 1, col = 0 } }
check("single-letter hint resolves to its match", hints.resolve(one, "s").row, 1)
check("a letter that is no hint", hints.resolve(one, "x"), nil)

local two = { { hint = "aa", row = 1 }, { hint = "as", row = 2 }, { hint = "sa", row = 3 } }
check("first letter of two-letter hints is partial", hints.resolve(two, "a"), "partial")
check("second letter resolves", hints.resolve(two, "as").row, 2)
check("wrong second letter", hints.resolve(two, "ax"), nil)
check("no matches at all", hints.resolve({}, "a"), nil)
check("missing matches table", hints.resolve(nil, "a"), nil)

print(string.format("%d checks, %d failed", count, failures))
os.exit(failures == 0 and 0 or 1)
