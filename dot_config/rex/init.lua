-- Rex key bindings migrated from tmux, Herdr, Ghostty and WezTerm.

-- Rex has no prefix setting; P is the first key of every sequence below.
local P = "ctrl+a"

-- The prefix key passes through to programs that use it.
rex.bind(P .. ">ctrl+a", "pane.send_key", { key = "ctrl+a" })

-- tmux: ~/.tmux.conf and ~/.tmux.conf.local
rex.mode("repeat", { exclusive = true })
rex.bind(P .. ">ctrl+r", "client.mode.enter", { name = "repeat" })
rex.bind("repeat/enter", "client.mode.exit")
rex.bind("repeat/escape", "client.mode.exit")

rex.bind(P .. ">e", "client.tab.new")
rex.bind(P .. ">ctrl+c", "session.new")
rex.bind(P .. ">-", "pane.split", { direction = "down" })
rex.bind(P .. ">shift+-", "pane.split", { direction = "right" })
rex.bind(P .. ">h", "pane.focus", { direction = "left" })
rex.bind("repeat/h", "pane.focus", { direction = "left" })
rex.bind(P .. ">j", "pane.focus", { direction = "down" })
rex.bind("repeat/j", "pane.focus", { direction = "down" })
rex.bind(P .. ">k", "pane.focus", { direction = "up" })
rex.bind("repeat/k", "pane.focus", { direction = "up" })
rex.bind(P .. ">shift+.", "pane.move", { direction = "down" })
rex.bind(P .. ">shift+,", "pane.move", { direction = "up" })
rex.bind(P .. ">shift+h", "pane.resize", { amount = 2, direction = "left" })
rex.bind("repeat/shift+h", "pane.resize", { amount = 2, direction = "left" })
rex.bind(P .. ">shift+j", "pane.resize", { amount = 2, direction = "down" })
rex.bind("repeat/shift+j", "pane.resize", { amount = 2, direction = "down" })
rex.bind(P .. ">shift+k", "pane.resize", { amount = 2, direction = "up" })
rex.bind("repeat/shift+k", "pane.resize", { amount = 2, direction = "up" })
rex.bind(P .. ">shift+l", "pane.resize", { amount = 2, direction = "right" })
rex.bind("repeat/shift+l", "pane.resize", { amount = 2, direction = "right" })
rex.bind(P .. ">ctrl+h", "client.tab.previous")
rex.bind("repeat/ctrl+h", "client.tab.previous")
rex.bind(P .. ">ctrl+l", "client.tab.next")
rex.bind("repeat/ctrl+l", "client.tab.next")

-- ~/.tmux.conf.local, loaded after ~/.tmux.conf
-- Like tmux's #{@pane-is-vim} check: keys go to (Neo)vim when it runs in the pane.
local function pane_runs_vim(ctx)
  local res = rex.call("com.superlogical.terminal.process",
    { session_id = ctx.session_id, block_id = ctx.block_id, args = {} })
  local name = res and res.foreground and res.foreground.name
  return name == "nvim" or name == "vim"
end

-- Keys are bound to functions, not action names: key presses only reach Lua bound as a function.
-- Returning false passes the key on to the pane; returning true keeps it.
local function vim_or_focus(direction)
  return function(ctx)
    if pane_runs_vim(ctx) then return false end
    rex.call("session.focus_direction", { session_id = ctx.session_id, direction = direction })
    return true
  end
end

-- Client actions (pane.resize, pane.send_key) can only be queued by an action, never by a key function.
rex.action{
  name = "vim_or_resize", title = "Send Key to Vim or Resize Pane",
  args = { key = "string", direction = "string" },
  run = function(ctx, args)
    if pane_runs_vim(ctx) then
      rex.client.queue("pane.send_key", { key = args.key })
    else
      rex.client.queue("pane.resize", { amount = 3, direction = args.direction })
    end
  end,
}

rex.bind("ctrl+h", vim_or_focus("left"))
rex.bind("ctrl+j", vim_or_focus("down"))
rex.bind("ctrl+k", vim_or_focus("up"))
rex.bind("ctrl+l", vim_or_focus("right"))
rex.bind("alt+h", "vim_or_resize", { key = "alt+h", direction = "left" })
rex.bind("alt+j", "vim_or_resize", { key = "alt+j", direction = "down" })
rex.bind("alt+k", "vim_or_resize", { key = "alt+k", direction = "up" })
rex.bind("alt+l", "vim_or_resize", { key = "alt+l", direction = "right" })
-- Change split direction: side by side <-> stacked, for the focused pane and its neighbour.
local layout = require("layout")

local function split_flip(ctx)
  local view = rex.call("session.view", { session_id = ctx.session_id })
  local move = layout.plan_flip(view, ctx.block_id)
  if not move then return end
  move.session_id = ctx.session_id
  rex.call("session.move_block", move)
end

rex.action{ name = "split_flip", title = "Change Split Direction", run = split_flip }
-- Bound to the function, not the action name: key presses only reach Lua bound as a function.
rex.bind(P .. ">space", function(ctx) split_flip(ctx) return true end)

-- extrakto: pick a word, path, URL or line from the pane in a floating fzf (~/.config/rex/bin/rex-extrakto).
local function extrakto(ctx)
    rex.call("session.new_layer", {
      session_id = ctx.session_id, focus = true, bounds = { 0.1, 0.1, 0.8, 0.8 },
      layout = { block = { flavor = "com.superlogical.terminal.shell", label = "extrakto", options = {
        command = { os.getenv("HOME") .. "/.config/rex/bin/rex-extrakto", ctx.session_id, ctx.block_id },
      } } },
    })
    return true
end
rex.action{ name = "extrakto", title = "Extract Text from Pane", run = extrakto }
rex.bind(P .. ">shift+e", extrakto)

rex.bind(P .. ">v", "pane.split", { direction = "right" })
rex.bind(P .. ">s", "pane.split", { direction = "down" })
rex.bind(P .. ">l", "pane.send_key", { key = "ctrl+l" })
rex.bind("ctrl+shift+up", "client.prompt.previous")
rex.bind("ctrl+shift+down", "client.prompt.next")

-- Herdr: ~/.config/herdr/config.toml
rex.bind(P .. ">shift+s", "client.settings")
rex.bind(P .. ">,", "client.tab.rename")
rex.bind("ctrl+shift+h", "client.tab.move", { direction = "backward" })
rex.bind("ctrl+shift+l", "client.tab.move", { direction = "forward" })

-- Ghostty: ~/.config/ghostty/config
rex.bind(P .. ">o", "pane.focus_next")
rex.bind(P .. ">;", "pane.focus_previous")
rex.bind(P .. ">shift+=", "pane.zoom")
rex.bind(P .. ">=", "pane.balance")
rex.bind(P .. ">x", "pane.close")
rex.bind(P .. ">c", "client.tab.new")
rex.bind(P .. ">shift+7", "client.tab.close")
rex.bind(P .. ">ctrl+shift+h", "client.tab.move", { direction = "backward" })
rex.bind(P .. ">ctrl+shift+l", "client.tab.move", { direction = "forward" })
rex.bind(P .. ">tab", "client.tab.goto", { index = -1 })
rex.bind(P .. ">1", "client.tab.goto", { index = 1 })
rex.bind(P .. ">2", "client.tab.goto", { index = 2 })
rex.bind(P .. ">3", "client.tab.goto", { index = 3 })
rex.bind(P .. ">4", "client.tab.goto", { index = 4 })
rex.bind(P .. ">5", "client.tab.goto", { index = 5 })
rex.bind(P .. ">6", "client.tab.goto", { index = 6 })
rex.bind(P .. ">7", "client.tab.goto", { index = 7 })
rex.bind(P .. ">8", "client.tab.goto", { index = 8 })
rex.bind(P .. ">9", "client.tab.goto", { index = 9 })
rex.bind(P .. ">shift+;", "client.palette.toggle")
rex.bind(P .. ">r", "client.config.reload")

-- WezTerm: ~/.wezterm.lua
rex.bind(P .. ">up", "client.prompt.previous")
rex.bind(P .. ">down", "client.prompt.next")
rex.bind(P .. ">z", "pane.zoom")
rex.bind(P .. ">left", "client.tab.move", { direction = "backward" })
rex.bind(P .. ">right", "client.tab.move", { direction = "forward" })
rex.bind(P .. ">p", "client.tab.previous")
rex.bind(P .. ">n", "client.tab.next")
rex.bind(P .. ">/", "client.find.open")
-- smart-splits.nvim resize keys (META is alt); its resize step is 3
rex.bind("alt+left", "vim_or_resize", { key = "alt+left", direction = "left" })
rex.bind("alt+down", "vim_or_resize", { key = "alt+down", direction = "down" })
rex.bind("alt+up", "vim_or_resize", { key = "alt+up", direction = "up" })
rex.bind("alt+right", "vim_or_resize", { key = "alt+right", direction = "right" })

