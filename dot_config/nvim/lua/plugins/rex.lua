-- Rex terminal multiplexer integration for smart-splits.nvim.
-- LazyVim merges this with lua/plugins/smart-splits.lua; delete this file to remove it.
return {
  "mrjones2014/smart-splits.nvim",
  opts = {
    -- Outside tmux, at Neovim's edge: move to the next Rex pane, else wrap (the default).
    at_edge = function(ctx)
      if vim.env.REX_SESSION then
        vim.fn.jobstart({ "rex", "focus", ctx.direction })
      else
        ctx.wrap()
      end
    end,
  },
}
