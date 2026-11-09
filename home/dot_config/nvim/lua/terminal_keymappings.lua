local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Map '<' to switch to the previous tab, and '>' to switch to the next tab.
keymap("n", "<", "gT", opts)
keymap("n", ">", "gt", opts)

-- Make "j" and "k" move through wrapped lines.
keymap({"n", "v"}, "j", "gj", opts)
keymap({"n", "v"}, "k", "gk", opts)
