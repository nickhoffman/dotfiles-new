#!/usr/bin/env bash
# Sets up a brand-new Mac (no old dotfiles) with chezmoi and checks the result. CI only.
set -uo pipefail
[[ "${CI:-}" == "true" ]] || { echo "Refusing to run outside CI." >&2; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/assert-lib.sh"

git clone --quiet "$GITHUB_WORKSPACE" "$HOME/src/dotfiles-new"
command -v chezmoi > /dev/null || brew install chezmoi
# Install Handy outside Homebrew's records, as a download from its website
# would be, so brew bundle has to adopt an app that's already in /Applications.
brew install --cask handy > /dev/null && rm -rf "$(brew --prefix)/Caskroom/handy"
started=$(date +%s)
DOTFILES_PROFILE=personal chezmoi init --apply --source "$HOME/src/dotfiles-new" < /dev/null; status=$?
echo "Setup took $(( $(date +%s) - started ))s, exit status $status"

check "chezmoi init --apply exits 0" test "$status" -eq 0
check "chezmoi verify passes" chezmoi verify
check "a second chezmoi apply changes nothing" idempotent_apply
check "zsh starts cleanly" zsh_ok 'exit 0'
check "oh-my-zsh is installed" test -d "$HOME/.oh-my-zsh"
check "ruby comes from the latest asdf" zsh_ok '[[ $(command -v ruby) == *asdf* ]] && ruby -e "require %q(awesome_print)"'
check "Homebrew packages are installed" zsh_ok 'command -v tmux && command -v tmuxp && command -v tree && command -v git-wtf'
check "Mac apps are installed" casks_installed "${common_casks[@]}" "${personal_casks[@]}"
check "the existing Handy app was adopted" test -d /Applications/Handy.app
check "Claude Code settings were created" grep -q '"model": "opus"' "$HOME/.claude/settings.json"
check "Rectangle preferences were imported" defaults read com.knollsoft.Rectangle
check "Alfred syncs to the new repo" test "$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder)" = "~/src/dotfiles-new/alfred"
# Alfred 5 reads its sync folder from prefs.json; the default above is only a copy.
alfred_prefs="$HOME/Library/Application Support/Alfred/prefs.json"
check "Alfred uses the preferences in the new repo" test "$(plutil -extract current raw "$alfred_prefs")" = "$HOME/src/dotfiles-new/alfred/Alfred.alfredpreferences"
check "Alfred 5 syncs to the new repo" test "$(plutil -extract syncfolders.5 raw "$alfred_prefs")" = "~/src/dotfiles-new/alfred"
check "work-only preferences were not imported" test -z "$(defaults read com.stripe.jil.meetingbar 2>/dev/null)"
check "VS Code key repeat is enabled" test "$(defaults read com.microsoft.VSCode ApplePressAndHoldEnabled)" = 0
finish
