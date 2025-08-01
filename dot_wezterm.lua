-- Pull in the wezterm API
local wezterm = require("wezterm")

local smart_splits = wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")

-- This will hold the configuration.
local config = wezterm.config_builder()

if string.match(wezterm.target_triple, "apple") then
	-- macOS-specific settings
	config.default_prog = { "/opt/homebrew/bin/fish", "-l" }
else
	-- Default settings for other platforms (e.g., Linux)
	config.default_prog = { "/home/linuxbrew/.linuxbrew/bin/fish", "-l" }
end

config.font = wezterm.font("0xProto Nerd Font")

-- wezterm.gui is not available to the mux server, so take care to
-- do something reasonable when this config is evaluated by the mux
local function get_appearance()
	return "Dark"
	-- if wezterm.gui then
	-- 	return wezterm.gui.get_appearance()
	-- end
	-- return "Dark"
end

config.window_background_opacity = 0.75

local custom_github_light = wezterm.color.get_builtin_schemes()["Github Light (Gogh)"]
config.color_schemes = {
	["Github Light (Gogh)"] = custom_github_light,
}

config.bold_brightens_ansi_colors = "BrightAndBold"

config.color_schemes["Github Light (Gogh)"] = custom_github_light

local function scheme_for_appearance(appearance)
	if appearance:find("Dark") then
		return "Catppuccin Mocha"
	else
		return "Catppuccin Latte"
	end
end

local appearance = get_appearance()
config.color_scheme = scheme_for_appearance(appearance)

local bar = wezterm.plugin.require("https://github.com/madhukar93/bar.wezterm")
bar.apply_to_config(config, {
	modules = {
		spotify = {
			enabled = false,
		},
	},
})

local act = wezterm.action

config.enable_scroll_bar = true
config.scrollback_lines = 100000
config.tab_bar_at_bottom = true
config.freetype_load_flags = "NO_HINTING"

config.enable_wayland = false

config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 2000 }

config.keys = {
	{ key = "UpArrow", mods = "SHIFT", action = act.ScrollByLine(-1) },
	{ key = "DownArrow", mods = "SHIFT", action = act.ScrollByLine(1) },
	{ key = "UpArrow", mods = "LEADER", action = act.ScrollToPrompt(-1) },
	{ key = "DownArrow", mods = "LEADER", action = act.ScrollToPrompt(1) },
	-- Basic window management
	{ key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "&", mods = "LEADER", action = act.CloseCurrentTab({ confirm = true }) },
	{ key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
	{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
	{ key = "LeftArrow", mods = "LEADER", action = act.MoveTabRelative(-1) },
	{ key = "RightArrow", mods = "LEADER", action = act.MoveTabRelative(1) },

	-- Window navigation

	{ key = "w", mods = "LEADER", action = act.ShowTabNavigator },
	{ key = "Tab", mods = "LEADER", action = act.ActivateLastTab },
	{ key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
	{ key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },

	-- Pane management
	{ key = "s", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "v", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "o", mods = "LEADER", action = act.ActivatePaneDirection("Next") },
	{ key = "}", mods = "LEADER", action = act.RotatePanes("Clockwise") },
	{ key = "{", mods = "LEADER", action = act.RotatePanes("CounterClockwise") },
	{ key = "q", mods = "LEADER", action = act.PaneSelect },
	--
	-- Copy mode (limited functionality compared to tmux)
	{ key = "[", mods = "LEADER", action = act.ActivateCopyMode },
	{ key = "]", mods = "LEADER", action = act.PasteFrom("Clipboard") },

	-- Other useful bindings
	{ key = ":", mods = "LEADER", action = act.ActivateCommandPalette },
	{ key = "r", mods = "LEADER", action = act.ReloadConfiguration },
	{ key = "?", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|KEY_ASSIGNMENTS" }) },

	-- Search in scrollback (similar to Vim's /)
	{ key = "/", mods = "LEADER", action = act.Search("CurrentSelectionOrEmptyString") },

	-- Quick split and run commands
	{
		key = "g",
		mods = "LEADER",
		action = act.SplitPane({
			direction = "Right",
			size = { Percent = 30 },
			command = { args = { "lazygit" } },
		}),
	},

	-- Rename current tab
	{
		key = ",",
		mods = "LEADER",
		action = act.PromptInputLine({
			description = "Enter new name for tab",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},
}

config.unix_domains = {
	{
		name = "madhukar-pc-tailscale",
		proxy_command = {
			"ssh",
			"-v",
			"-J",
			"madhukar@madhukar-pc.tailce84f.ts.net",
			"madhukar@127.0.0.1",
			"-Y",
			"wezterm",
			"cli",
			"proxy",
		},
	},
}

-- https://github.com/mrjones2014/smart-splits.nvim?tab=readme-ov-file#usage
smart_splits.apply_to_config(config, {
	direction_keys = {
		move = { "h", "j", "k", "l" },
		resize = { "LeftArrow", "DownArrow", "UpArrow", "RightArrow" },
	},
	modifiers = {
		move = "CTRL",
		resize = "META",
	},
})

return config
