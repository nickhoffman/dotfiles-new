#!/usr/bin/env bash
# Sets up a brand-new Mac (no old dotfiles) with chezmoi and checks the result. CI only.
set -uo pipefail
[[ "${CI:-}" == "true" ]] || { echo "Refusing to run outside CI." >&2; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/assert-lib.sh"

git clone --quiet "$GITHUB_WORKSPACE" "$HOME/src/dotfiles-new"
command -v chezmoi > /dev/null || brew install chezmoi

# A brew wrapper, first on PATH, that logs each brew command to $BREW_LOG and
# makes `brew update` fail when $BREW_UPDATE_FAILS is set.
shim="$RUNNER_TEMP/brew-shim"; mkdir -p "$shim"
cat > "$shim/brew" <<SHIM
#!/bin/bash
echo "\$*" >> "\${BREW_LOG:-/dev/null}"
if [[ \${1:-} == update && -n \${BREW_UPDATE_FAILS:-} ]]; then echo "simulated brew update failure" >&2; exit 1; fi
exec $(command -v brew) "\$@"
SHIM
chmod +x "$shim/brew"
# True if the brew log has `brew update` before the first `brew bundle`.
updated_before_bundle() { awk '/^update/ { u=1 } /^bundle/ { b=1; exit } END { exit !(u && b) }' "$1"; }
not_in_log() { ! grep -q "$1" "$2"; }
in_log() { grep -q "$1" "$2"; }

started=$(date +%s)
BREW_LOG="$RUNNER_TEMP/brew-init.log" PATH="$shim:$PATH" \
  DOTFILES_PROFILE=personal chezmoi init --apply --source "$HOME/src/dotfiles-new" < /dev/null; status=$?
echo "Setup took $(( $(date +%s) - started ))s, exit status $status"

check "chezmoi init --apply exits 0" test "$status" -eq 0
check "brew update runs before brew bundle" updated_before_bundle "$RUNNER_TEMP/brew-init.log"
check "chezmoi verify passes" chezmoi verify
check "a second chezmoi apply changes nothing" idempotent_apply
check "zsh starts cleanly" zsh_ok 'exit 0'
check "oh-my-zsh is installed" test -d "$HOME/.oh-my-zsh"
check "ruby comes from the latest asdf" zsh_ok '[[ $(command -v ruby) == *asdf* ]] && ruby -e "require %q(awesome_print)"'
check "Homebrew packages are installed" zsh_ok 'command -v tmux && command -v tmuxp && command -v tree && command -v git-wtf'
check "Claude Code settings were created" grep -q '"model": "opus"' "$HOME/.claude/settings.json"
check "Rectangle preferences were imported" defaults read com.knollsoft.Rectangle
check "Alfred syncs to the new repo" test "$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder)" = "~/src/dotfiles-new/alfred"
check "work-only preferences were not imported" test -z "$(defaults read com.stripe.jil.meetingbar 2>/dev/null)"
check "VS Code key repeat is enabled" test "$(defaults read com.microsoft.VSCode ApplePressAndHoldEnabled)" = 0

# Last, because it forgets which run_onchange scripts have run: make every one
# run again, with `brew update` failing.
chezmoi state delete-bucket --bucket=entryState
BREW_UPDATE_FAILS=1 BREW_LOG="$RUNNER_TEMP/brew-fail.log" PATH="$shim:$PATH" chezmoi apply --include=scripts < /dev/null; status=$?
check "a failed brew update fails chezmoi apply" test "$status" -ne 0
check "brew update ran" in_log '^update' "$RUNNER_TEMP/brew-fail.log"
check "brew bundle doesn't run after brew update fails" not_in_log '^bundle' "$RUNNER_TEMP/brew-fail.log"
finish
