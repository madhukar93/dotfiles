return {
  "mrjones2014/smart-splits.nvim",
  tag = "v2.1.1-final",
  lazy = false,
  opts = {
    ignored_filetypes = {
      "nofile",
      "quickfix",
      "qf",
      "prompt",
    },
    ignored_buftypes = { "nofile" },
    -- At the last Neovim split: inside Rex (and not tmux), move to the next Rex pane; otherwise wrap.
    at_edge = function(ctx)
      if vim.env.REX_SESSION and not vim.env.TMUX then
        vim.system({ "rex", "focus", "-s", vim.env.REX_SESSION, ctx.direction })
      else
        ctx.wrap()
      end
    end,
  },
  keys = {
    {
      "<C-h>",
      function()
        require("smart-splits").move_cursor_left()
      end,
      desc = "Move to left split",
    },
    {
      "<C-j>",
      function()
        require("smart-splits").move_cursor_down()
      end,
      desc = "Move to below split",
    },
    {
      "<C-k>",
      function()
        require("smart-splits").move_cursor_up()
      end,
      desc = "Move to above split",
    },
    {
      "<C-l>",
      function()
        require("smart-splits").move_cursor_right()
      end,
      desc = "Move to right split",
    },
    {
      "<A-Left>",
      function()
        require("smart-splits").resize_left()
      end,
      desc = "Resize left",
    },
    {
      "<A-Down>",
      function()
        require("smart-splits").resize_down()
      end,
      desc = "Resize down",
    },
    {
      "<A-Up>",
      function()
        require("smart-splits").resize_up()
      end,
      desc = "Resize up",
    },
    {
      "<A-Right>",
      function()
        require("smart-splits").resize_right()
      end,
      desc = "Resize right",
    },
  },
}
