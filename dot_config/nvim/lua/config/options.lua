-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- tmux integration only inside tmux; elsewhere (Rex) smart-splits uses its at_edge function
vim.g.smart_splits_multiplexer_integration = vim.env.TMUX and "tmux" or false
vim.opt.relativenumber = false
