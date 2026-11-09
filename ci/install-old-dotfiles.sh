#!/usr/bin/env bash
# Rebuilds a Mac's pre-migration state: the old linker.sh setup from
# github.com/nickhoffman/dotfiles at a pinned commit, cloned to ~/src/dotfiles
# like on the real Macs. CI only: this changes the machine it runs on.
set -euo pipefail
: "${OLD_DOTFILES_SHA:?set OLD_DOTFILES_SHA}"

if [[ "${CI:-}" != "true" ]]; then
  echo "Refusing to run outside CI." >&2
  exit 1
fi

# Prints a timestamped phase header, so the log shows how long each phase took.
phase() { echo "### [$(date -u +%H:%M:%S)] $*"; }

# Runs a command, killing it after N seconds (macOS has no timeout(1)).
with_time_limit() { local secs=$1; shift; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; }

repo="$HOME/src/dotfiles"
git clone https://github.com/nickhoffman/dotfiles "$repo"
git -C "$repo" checkout --quiet "$OLD_DOTFILES_SHA"

# linker.sh requires a writable /usr/local/bin.
sudo mkdir -p /usr/local/bin
sudo chown "$(id -un)" /usr/local/bin

phase "Installing the Mac apps whose preferences linker.sh imports"
# Not iTerm2 (replaced by Ghostty) or MeetingBar (a private fork on the work Mac).
apps=(ghostty rectangle alt-tab alfred bartender cleanshot)
with_time_limit 900 brew install --cask "${apps[@]}"

phase "Launching each app once so it writes its first-run preferences"
# Open by path: right after install, Launch Services may not know the app names yet.
for path in /Applications/{Ghostty,Rectangle,AltTab,"Alfred 5","Bartender 7","CleanShot X"}.app; do
  name=$(basename "$path" .app)
  if open -g "$path"; then
    sleep 10
    osascript -e "quit app \"$name\"" || true
    sleep 2
    pkill -9 -f "$path/Contents/MacOS/" || true
    echo "Launched and quit $name"
  else
    echo "WARNING: could not launch $path"
  fi
done

phase "Installing oh-my-zsh (unattended)"
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

phase "Running linker.sh, answering y to every prompt"
# Homebrew reads stdin and swallowed every answer meant for later prompts.
# A person doesn't type during `brew install`, so give brew no input.
shims="$RUNNER_TEMP/shims"
mkdir -p "$shims"
printf '#!/bin/sh\nexec %s "$@" < /dev/null\n' "$(command -v brew)" > "$shims/brew"
chmod +x "$shims/brew"
export PATH="$shims:$PATH"

# Entries of home/ that already exist as real directories are skipped by linker.sh.
preexisting=()
for f in "$repo"/home/.[^.]*; do
  t="$HOME/$(basename "$f")"
  if [[ -d $t && ! -L $t ]]; then preexisting+=("$(basename "$f")"); fi
done
echo "Already directories, linker.sh will skip: ${preexisting[*]:-none}"

# linker.sh reads single keypresses (read -n 1), so send y's with no newlines.
# The input is finite on purpose: an endless `yes` kept the pipeline running
# after linker.sh exited.
cd "$repo"
set +eo pipefail
perl -e 'print "y" x 100000' | with_time_limit 1800 ./linker.sh
status=${PIPESTATUS[1]}
set -eo pipefail
phase "linker.sh exit status: $status"
[[ $status -eq 0 ]] || exit "$status"

phase "Checking that every prompt was answered y"
failed=0
for f in "$repo"/home/.[^.]*; do
  b=$(basename "$f"); t="$HOME/$b"
  if [[ " ${preexisting[*]:-} " == *" $b "* ]]; then continue; fi
  if [[ "$(readlink "$t" || true)" != "$f" ]]; then
    echo "ERROR: ~/$b is not a symlink to $f"; failed=1
  fi
done
for f in "$repo"/bin/*; do
  t="/usr/local/bin/$(basename "$f")"
  [[ "$(readlink "$t" || true)" == "$f" ]] || { echo "ERROR: $t is not a symlink to $f"; failed=1; }
done
[[ -d "$HOME/.asdf/installs/ruby" ]] || { echo "ERROR: asdf Ruby was not installed"; failed=1; }
exit "$failed"
