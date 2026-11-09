local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Map ';' to swap the position of the current line and the one below it.
keymap("n", ";", "ddpk0", opts)
