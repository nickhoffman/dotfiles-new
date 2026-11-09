local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- remap leader key
keymap("n", "<Space>", "", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- START: Config from https://medium.com/@nikmas_dev/vscode-neovim-setup-keyboard-centric-powerful-reliable-clean-and-aesthetic-development-582d34297985

-- yank to system clipboard
keymap({"n", "v"}, "<leader>y", '"+y', opts)

-- paste from system clipboard
keymap({"n", "v"}, "<leader>p", '"+p', opts)

-- better indent handling
--keymap("v", "<", "<gv", opts)
--keymap("v", ">", ">gv", opts)

-- move text up and down
--keymap("v", "J", ":m .+1<CR>==", opts)
--keymap("v", "K", ":m .-2<CR>==", opts)
--keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
--keymap("x", "K", ":move '<-2<CR>gv-gv", opts)

-- paste preserves primal yanked piece
--keymap("v", "p", '"_dP', opts)

-- removes highlighting after escaping vim search
keymap("n", "<Esc>", "<Esc>:noh<CR>", opts)

-- call vscode commands from neovim

-- general keymaps
keymap({"n", "v"}, "<leader>t", "<cmd>lua require('vscode').action('workbench.action.terminal.toggleTerminal')<CR>")
keymap({"n", "v"}, "<leader>b", "<cmd>lua require('vscode').action('editor.debug.action.toggleBreakpoint')<CR>")
keymap({"n", "v"}, "<leader>d", "<cmd>lua require('vscode').action('editor.action.showHover')<CR>")
keymap({"n", "v"}, "<leader>a", "<cmd>lua require('vscode').action('editor.action.quickFix')<CR>")
keymap({"n", "v"}, "<leader>sp", "<cmd>lua require('vscode').action('workbench.actions.view.problems')<CR>")
keymap({"n", "v"}, "<leader>cn", "<cmd>lua require('vscode').action('notifications.clearAll')<CR>")
keymap({"n", "v"}, "<leader>ff", "<cmd>lua require('vscode').action('workbench.action.quickOpen')<CR>")
keymap({"n", "v"}, "<leader>cp", "<cmd>lua require('vscode').action('workbench.action.showCommands')<CR>")
keymap({"n", "v"}, "<leader>pr", "<cmd>lua require('vscode').action('code-runner.run')<CR>")
keymap({"n", "v"}, "<leader>fd", "<cmd>lua require('vscode').action('editor.action.formatDocument')<CR>")

-- END: Config from https://medium.com/@nikmas_dev/vscode-neovim-setup-keyboard-centric-powerful-reliable-clean-and-aesthetic-development-582d34297985

-- Map '<' to switch to the previous tab, and '>' to switch to the next tab.
keymap("n", "<", "<cmd>lua require('vscode').action('workbench.action.previousEditor')<CR>")
keymap("n", ">", "<cmd>lua require('vscode').action('workbench.action.nextEditor')<CR>")

-- Make it easier to switch between split viewports.
keymap("n", "<C-h>", "<cmd>lua require('vscode').action('workbench.action.focusPreviousGroup')<CR>")
keymap("n", "<C-l>", "<cmd>lua require('vscode').action('workbench.action.focusNextGroup')<CR>")

-- Make "j" and "k" move through wrapped lines (VS Code)
keymap("n", "j", "<cmd>lua require('vscode').action('cursorDown')<CR>", opts)
keymap("n", "k", "<cmd>lua require('vscode').action('cursorUp')<CR>", opts)