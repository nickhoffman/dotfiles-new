#!/usr/bin/env bash
# Runs inside a fresh Ubuntu container as a normal user with passwordless sudo
# and no terminal, like a devbox init script. CI only.
#   devbox.sh LOCAL_SOURCE_DIR [github]
set -uo pipefail
src="${1:?source dir}"; mode="${2:-local}"
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/assert-lib.sh"
[[ -t 0 ]] && { echo "Expected no terminal."; exit 1; }

echo "== A missing profile fails fast instead of hanging"
start=$(date +%s)
out=$(env -u DOTFILES_PROFILE timeout 60 sh -c "$(curl -fsLS --retry 5 --retry-all-errors get.chezmoi.io)" -- -b "$HOME/.local/bin" init --source "$src" 2>&1 < /dev/null); rc=$?
check "chezmoi init without a profile fails" test "$rc" -ne 0 -a "$rc" -ne 124
check "the error names DOTFILES_PROFILE" grep -q DOTFILES_PROFILE <<< "$out"
check "it fails within 30 seconds" test $(( $(date +%s) - start )) -lt 30
rm -rf "$HOME/.config/chezmoi"

echo "== Bootstrap"
start=$(date +%s)
if [[ $mode == github ]]; then
  # The exact one-liner from the README, against the repo on GitHub.
  DOTFILES_PROFILE=devbox sh -c "$(curl -fsLS --retry 5 --retry-all-errors get.chezmoi.io)" -- -b ~/.local/bin init --apply nickhoffman/dotfiles-new < /dev/null; rc=$?
else
  DOTFILES_PROFILE=devbox sh -c "$(curl -fsLS --retry 5 --retry-all-errors get.chezmoi.io)" -- -b ~/.local/bin init --apply --source "$src" < /dev/null; rc=$?
fi
echo "Bootstrap took $(( $(date +%s) - start ))s"
export PATH="$HOME/.local/bin:$PATH"
check "bootstrap exits 0" test "$rc" -eq 0
check "chezmoi verify passes" chezmoi verify
check "a second chezmoi apply changes nothing" idempotent_apply
check "tmux, vim and tree are installed" sh -c 'command -v tmux && command -v vim && command -v tree'
check "~/.tmux.conf and ~/.tmux-linux.conf exist" test -f ~/.tmux.conf -a -f ~/.tmux-linux.conf
check "vim plugins from archives exist" test -f ~/.vim/bundle/vim-prettier/README.md -a -d ~/.vim/bundle/vim-graphql
check "git settings are in ~/.config/git/config" git config --global --get diff.algorithm
check "no osxkeychain credential helper" test -z "$(git config --get credential.helper)"
check "~/.gitconfig is left to the machine" test ! -e ~/.gitconfig
check "no zsh or Mac files" test ! -e ~/.zshrc -a ! -e ~/.zprofile -a ! -e ~/.p10k.zsh -a ! -e ~/.config/ghostty
check "Claude Code settings have the devbox keys" grep -q '"model": "opus"' ~/.claude/settings.json
check "no Mac-only Claude Code settings" sh -c '! grep -q osascript ~/.claude/settings.json'
check "bash loads the shared aliases" bash -ic 'alias ll' < /dev/null
finish
