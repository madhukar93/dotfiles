-- Markdown preview inside the editor instead of in a browser window.
--
-- LazyVim's markdown extra installs two plugins and binds the obvious key to
-- the wrong one for this purpose:
--   <leader>cp  -> markdown-preview.nvim, which opens a browser window
--   <leader>um  -> render-markdown.nvim, which renders inside the buffer
--
-- render-markdown.nvim was already installed and already running; LazyVim just
-- configures it very plainly (no heading icons, checkboxes off), so it is easy
-- to miss. This file makes the in-editor rendering look like a real preview and
-- moves it onto <leader>cp. The browser preview is still there on <leader>cP.
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      -- LazyVim blanks these out. Turned back on so rendered text actually
      -- reads as a preview. The terminal font is a Nerd Font, so the glyphs
      -- below will display.
      heading = {
        sign = false,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      checkbox = {
        enabled = true,
      },
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
      },
      -- Show the raw text of whichever line the cursor is on, so the file
      -- stays editable while the rest of the document renders.
      anti_conceal = {
        enabled = true,
      },
    },
    keys = {
      {
        "<leader>cp",
        ft = "markdown",
        function()
          -- render-markdown is on all the time, so a plain toggle looks like
          -- nothing happened. Open a dedicated preview tab instead: same
          -- window, no gutters, q to close.
          if vim.bo.filetype ~= "markdown" then
            vim.notify("Not a markdown buffer", vim.log.levels.WARN)
            return
          end
          require("render-markdown").enable()
          vim.cmd("tab split")
          local win = vim.api.nvim_get_current_win()
          for opt, val in pairs({
            number = false,
            relativenumber = false,
            signcolumn = "no",
            list = false,
            cursorline = false,
            foldcolumn = "0",
          }) do
            vim.api.nvim_set_option_value(opt, val, { win = win })
          end
          vim.keymap.set("n", "q", "<cmd>tabclose<cr>", {
            buffer = true,
            desc = "Close markdown preview",
          })
          vim.notify("Markdown preview - press q to close", vim.log.levels.INFO)
        end,
        desc = "Markdown Preview (tab in this window)",
      },
    },
  },

  {
    "iamcco/markdown-preview.nvim",
    -- Replace LazyVim's key list rather than adding to it, so <leader>cp no
    -- longer opens a browser. Returning a table from `keys` overrides.
    keys = function(_, _)
      return {
        {
          "<leader>cP",
          ft = "markdown",
          "<cmd>MarkdownPreviewToggle<cr>",
          desc = "Markdown Preview (browser)",
        },
      }
    end,
  },
}
