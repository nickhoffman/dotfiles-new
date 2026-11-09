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
    check "git-wtf runs from ~/.local/bin" zsh_ok '[[ $(command -v git-wtf) == $HOME/.local/bin/git-wtf ]]'
    check "/usr/local/bin/git-wtf link is gone" test ! -e /usr/local/bin/git-wtf
    check "ruby comes from asdf" zsh_ok '[[ $(command -v ruby) == *asdf* ]] && ruby -e "require %q(awesome_print)"'
    check "Homebrew packages are installed" zsh_ok 'command -v tmux && command -v tmuxp && command -v tree'
    check "statusline script no longer points into the old repo" grep -q 'caveman_script="$HOME/.claude/plugins/' "$HOME/.claude/statusline-command.sh"
    check "Claude Code settings are byte-for-byte unchanged" same_file "$settings_before" "$HOME/.claude/settings.json"
    check "Alfred syncs to the new repo" test "$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder)" = "~/src/dotfiles-new/alfred"
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
    check "zsh starts cleanly" zsh_ok 'exit 0'
    diff "$out/before/home-entries.txt" "$out/after/home-entries.txt"
    ;;
  abort-local-edit)
    "$migrate" --profile personal --yes; status=$?
    "$here/snapshot.sh" "$out/after" > /dev/null 2>&1
    check "migration refuses (non-zero exit)" test "$status" -ne 0
    check "every ~ entry is back to its baseline state" same_file "$out/before/home-entries.txt" "$out/after/home-entries.txt"
    check "the local edit survives" test "$(shasum -a 256 "$HOME/.zshrc" | cut -d' ' -f1)" = "$seeded_extra"
    check "all planted app data is intact" seeded_data_intact "$seeded"
    check "the old repo is unchanged (apart from the edit)" old_repo_unchanged "$out/before"
    check "the log names the edited file" grep -q '~/.zshrc' "$(ls -1d "$HOME"/.dotfiles-migration/*/ | tail -1)/log.txt"
    ;;
  *) echo "Unknown scenario $scenario"; exit 2 ;;
esac
finish
