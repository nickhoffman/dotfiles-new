-- START: Move these configs to separate file.
vim.opt.ignorecase = true
-- END: Move these configs to separate file.

require "keymappings"

if vim.g.vscode then
  -- VSCode Neovim
  require "vscode_keymappings"
else
  -- Ordinary Neovim
  vim.wo.number = true
  require "terminal_keymappings"

  -- Load the config from ~/.config/vimrc.vim
  local vimrc = vim.fn.stdpath("config") .. "/vimrc.vim"
  vim.cmd.source(vimrc)
end
