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

