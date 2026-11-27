#!/usr/bin/env bash
# Runs one migration scenario on a baseline Mac. CI only.
#   scenario.sh migrate-personal|migrate-work|rollback|abort-local-edit
set -uo pipefail
scenario="${1:?scenario name}"
[[ "${CI:-}" == "true" ]] || { echo "Refusing to run outside CI." >&2; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/assert-lib.sh"
out="$RUNNER_TEMP/out"; mkdir -p "$out"
seeded="$RUNNER_TEMP/baseline/seeded-data.sha256"
migrate="$HOME/src/dotfiles-new/tools/migrate-mac.sh"

# The new repo, at the commit under test, where the Macs keep it.
git clone --quiet "$GITHUB_WORKSPACE" "$HOME/src/dotfiles-new"

if [[ $scenario == abort-local-edit ]]; then
  # A local edit on the Mac that isn't in the old repo's commits.
  echo "alias local_edit_only_on_this_mac=true" >> "$HOME/.zshrc"
  seeded_extra=$(shasum -a 256 "$HOME/.zshrc" | cut -d' ' -f1)
fi

"$here/snapshot.sh" "$out/before" > /dev/null 2>&1
alfred_before=$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder 2>/dev/null)
rectangle_before=$(defaults read com.knollsoft.Rectangle 2>/dev/null | shasum -a 256)
alfred_prefs="$HOME/Library/Application Support/Alfred/prefs.json"
cp "$alfred_prefs" "$out/alfred-prefs-before.json"
alfred_pref() { plutil -extract "$1" raw "$alfred_prefs"; }

# The old repo's ~/.zshrc, loading Powerlevel10k from wherever Homebrew put it.
shared_zshrc() {
  local line old='source "$HOMEBREW_PREFIX/opt/powerlevel10k/powerlevel10k.zsh-theme"'
  while IFS= read -r line; do
    if [[ $line == "$old" ]]; then
      cat <<'P10K'
# Homebrew's powerlevel10k formula puts the theme in share/; the old
# romkatv/powerlevel10k tap's formula puts it at the top of its keg.
for p10k_theme in "$HOMEBREW_PREFIX"/{share,opt}/powerlevel10k/powerlevel10k.zsh-theme; do
  [[ -f $p10k_theme ]] && { source "$p10k_theme"; break; }
done
unset p10k_theme
P10K
    else
      printf '%s\n' "$line"
    fi
  done < "$HOME/src/dotfiles/home/.zshrc"
}

# Prints the path of the ~/.zshrc a profile should get: the shared one, and on
# the work Mac, wrapped in the Stripe config that Chef and island add there.
expected_zshrc() { # profile
  local f="$out/expected-zshrc-$1"
  if [[ $1 == work ]]; then
    {
      cat <<'TOP'
### BEGIN STRIPE
# All Stripe related shell configuration
# is at ~/.stripe/shellinit/zshrc and is
# persistently managed by Chef. You shouldn't
# remove this unless you don't want to load
# Stripe specific shell configurations.
#
# Feel free to add your customizations in this
# file (~/.zshrc) after the Stripe config
# is sourced.
if [[ -f ~/.stripe/shellinit/zshrc ]]; then
  source ~/.stripe/shellinit/zshrc
fi
### END STRIPE
TOP
      shared_zshrc
      cat <<'BOTTOM'

# island shell integration
[[ -f "$HOME/.config/island/island-shell-integration.zsh" ]] && source "$HOME/.config/island/island-shell-integration.zsh"
BOTTOM
    } > "$f"
  else
    shared_zshrc > "$f"
  fi
  echo "$f"
}

# Formulae (--formula) or casks (--cask) the brew bundle install script installs
# on this Mac's profile. The work Mac gets git from Stripe's git-stripe, which
# conflicts with Homebrew's git.
bundle_list() {
  local script entries
  script=$(chezmoi execute-template < "$HOME/src/dotfiles-new/home/.chezmoiscripts/run_onchange_after_20-brew-bundle.sh.tmpl") || return 1
  entries=$(sed -n '/^brew bundle/,/^BREWFILE$/p' <<< "$script" | sed '1d;$d' | brew bundle list "$1" --file=-) || return 1
  [[ -n $entries ]] || { echo "  the Brewfile lists nothing for $1" >&2; return 1; }
  echo "$entries"
}
# Reads the whole list before matching: with pipefail, `grep -q` exiting early
# can fail the pipeline with SIGPIPE.
bundle_has_formula() { local f; f=$(bundle_list --formula) && grep -qx "$1" <<< "$f"; }
bundle_lacks_formula() { local f; f=$(bundle_list --formula) && ! grep -qx "$1" <<< "$f"; }
bundle_lacks_cask() { local f; f=$(bundle_list --cask) && ! grep -qx "$1" <<< "$f"; }
# True if the app preferences script doesn't import this domain on this Mac's profile.
prefs_script_lacks() {
  local script
  script=$(chezmoi execute-template < "$HOME/src/dotfiles-new/home/.chezmoiscripts/run_onchange_after_50-mac-app-preferences.sh.tmpl") || return 1
  ! grep -qF "$1" <<< "$script"
}
# True if the asdf Ruby install script renders to nothing on this Mac's profile,
# so chezmoi has nothing to run. The work Mac's Santa blocks Rubies built on it.
asdf_ruby_script_is_empty() {
  local script
  script=$(chezmoi execute-template < "$HOME/src/dotfiles-new/home/.chezmoiscripts/run_onchange_after_40-asdf-ruby.sh.tmpl") || return 1
  [[ -z $script ]]
}
# The manual-install reminders script, rendered for this Mac's profile.
reminders_script() { chezmoi execute-template < "$HOME/src/dotfiles-new/home/.chezmoiscripts/run_onchange_after_70-manual-install-reminders.sh.tmpl"; }
# True if running the reminders script prints $1. CI runners lack these apps, so
# every reminder fires. Captures the output before matching: with pipefail,
# `grep -q` exiting early can fail the pipeline with SIGPIPE.
reminders_script_prints() { local s o; s=$(reminders_script) && o=$(bash -c "$s" 2>&1) && grep -qF "$1" <<< "$o"; }
reminders_script_lacks() { local s; s=$(reminders_script) && ! grep -qF "$1" <<< "$s"; }

case "$scenario" in
  migrate-personal|migrate-work)
    profile=${scenario#migrate-}
    settings_before="$out/settings-before.json"; cp "$HOME/.claude/settings.json" "$settings_before"
    started=$(date +%s)
    "$migrate" --profile "$profile" --yes; status=$?
    echo "Migration took $(( $(date +%s) - started ))s, exit status $status"
    state=$(ls -1d "$HOME"/.dotfiles-migration/*/ | tail -1); cp -R "$state" "$out/migration-state"; rm -f "$out/migration-state/old-repo.tar.gz"
    check "migration exits 0" test "$status" -eq 0
    check "no symlinks into the old repo remain" no_links_into_old_repo
    check "~/.config is a real directory" test -d "$HOME/.config" -a ! -L "$HOME/.config"
    check "~/.claude is a real directory" test -d "$HOME/.claude" -a ! -L "$HOME/.claude"
    check "all planted app data is intact" seeded_data_intact "$seeded"
    check "the old repo is unchanged" old_repo_unchanged "$out/before"
    check "the old repo backup tarball exists" test -s "$state/old-repo.tar.gz"
    check "chezmoi verify passes" chezmoi verify
    check "a second chezmoi apply changes nothing" idempotent_apply
    check "zsh starts cleanly" zsh_ok 'exit 0'
    check "Powerlevel10k loads" zsh_ok "(( \$+functions[p10k] ))"
    check "~/.zshrc is the $profile one" same_file "$(expected_zshrc "$profile")" "$HOME/.zshrc"
    check "git-wtf runs from ~/.local/bin" zsh_ok '[[ $(command -v git-wtf) == $HOME/.local/bin/git-wtf ]]'
    check "/usr/local/bin/git-wtf link is gone" test ! -e /usr/local/bin/git-wtf
    check "Homebrew packages are installed" zsh_ok 'command -v tmux && command -v tmuxp && command -v tree'
    check "Mac apps for every Mac are installed" casks_installed "${common_casks[@]}"
    check "CleanShot is not in the Brewfile" bundle_lacks_cask cleanshot
    check "CleanShot preferences are not imported" prefs_script_lacks pl.maketheweb.cleanshotx
    check "BetterTouchTool is not in the Brewfile" bundle_lacks_cask bettertouchtool
    check "Ghostty starts new windows in ~" grep -qx 'working-directory = home' "$HOME/.config/ghostty/config"
    if [[ $profile == personal ]]; then
      check "personal Mac apps are installed" casks_installed "${personal_casks[@]}"
      check "Homebrew's git is in the Brewfile" bundle_has_formula git
      check "ruby comes from asdf" zsh_ok '[[ $(command -v ruby) == *asdf* ]] && ruby -e "require %q(awesome_print)"'
      check "chezmoi reminds me to install BetterTouchTool" reminders_script_prints "Download BetterTouchTool"
      check "chezmoi reminds me to install Monosnap" reminders_script_prints "Download Monosnap"
    else
      check "personal Mac apps are not installed" none_installed "${personal_casks[@]}"
      check "Homebrew's git is left to git-stripe" bundle_lacks_formula git
      check "the asdf Ruby script doesn't run" asdf_ruby_script_is_empty
      check "chezmoi doesn't remind me to install BetterTouchTool" reminders_script_lacks BetterTouchTool
      check "chezmoi doesn't remind me to install Monosnap" reminders_script_lacks Monosnap
    fi
    check "statusline script no longer points into the old repo" grep -q 'caveman_script="$HOME/.claude/plugins/' "$HOME/.claude/statusline-command.sh"
    check "Claude Code settings are byte-for-byte unchanged" same_file "$settings_before" "$HOME/.claude/settings.json"
    check "Alfred syncs to the new repo" test "$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder)" = "~/src/dotfiles-new/alfred"
    check "Alfred uses the preferences in the new repo" test "$(alfred_pref current)" = "$HOME/src/dotfiles-new/alfred/Alfred.alfredpreferences"
    check "Alfred 5 syncs to the new repo" test "$(alfred_pref syncfolders.5)" = "~/src/dotfiles-new/alfred"
    check "Alfred keeps its local hash" test "$(alfred_pref localhash)" = 73ce1a76e26060e47f2b0dd000b1598449deacc8
    check "Alfred's untracked local preference moved with it" test -f "$HOME/src/dotfiles-new/alfred/Alfred.alfredpreferences/preferences/local/73ce1a76e26060e47f2b0dd000b1598449deacc8/appearance/prefs.plist"
    check "existing app preferences were not overwritten" test "$(defaults read com.knollsoft.Rectangle 2>/dev/null | shasum -a 256)" = "$rectangle_before"
    ;;
  rollback)
    "$migrate" --profile personal --yes; mstatus=$?
    check "migration exits 0" test "$mstatus" -eq 0
    "$migrate" --rollback; rstatus=$?
    check "rollback exits 0" test "$rstatus" -eq 0
    "$here/snapshot.sh" "$out/after" > /dev/null 2>&1
    check "every ~ entry is back to its baseline state" same_file "$out/before/home-entries.txt" "$out/after/home-entries.txt"
    check "/usr/local/bin links are back" same_file "$out/before/usr-local-bin-links.txt" "$out/after/usr-local-bin-links.txt"
    check "all planted app data is intact through the old links" seeded_data_intact "$seeded"
    check "the old repo is unchanged" old_repo_unchanged "$out/before"
    check "Alfred's sync folder is restored" test "$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder)" = "$alfred_before"
    check "Alfred's prefs.json is restored" same_file "$out/alfred-prefs-before.json" "$alfred_prefs"
    check "zsh starts cleanly" zsh_ok 'exit 0'
    diff "$out/before/home-entries.txt" "$out/after/home-entries.txt"
    ;;
  abort-local-edit)
    "$migrate" --profile personal --yes; status=$?
    "$here/snapshot.sh" "$out/after" > /dev/null 2>&1
    check "migration refuses (non-zero exit)" test "$status" -ne 0
    check "every ~ entry is back to its baseline state" same_file "$out/before/home-entries.txt" "$out/after/home-entries.txt"
    check "the local edit survives" test "$(shasum -a 256 "$HOME/.zshrc" | cut -d' ' -f1)" = "$seeded_extra"
    check "Alfred's prefs.json is unchanged" same_file "$out/alfred-prefs-before.json" "$alfred_prefs"
    check "all planted app data is intact" seeded_data_intact "$seeded"
    check "the old repo is unchanged (apart from the edit)" old_repo_unchanged "$out/before"
    check "the log names the edited file" grep -q '~/.zshrc' "$(ls -1d "$HOME"/.dotfiles-migration/*/ | tail -1)/log.txt"
    ;;
  *) echo "Unknown scenario $scenario"; exit 2 ;;
esac
finish
