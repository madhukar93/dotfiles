-- The mini-diff extra disables gitsigns; re-enable it only for inline blame.
-- Gutter signs stay with mini.diff (signcolumn = false avoids duplicates).
return {
  "lewis6991/gitsigns.nvim",
  enabled = true,
  opts = { signcolumn = false, current_line_blame = true },
}
