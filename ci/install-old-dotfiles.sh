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
for app in Ghostty Rectangle AltTab "Alfred 5" "Bartender 6" "CleanShot X"; do
  if open -a "$app"; then
    sleep 10
    osascript -e "quit app \"$app\"" || pkill -x "$app" || true
    sleep 2
    pgrep -x "$app" > /dev/null && pkill -9 -x "$app"
    echo "Launched and quit $app"
  else
    echo "WARNING: could not launch $app"
  fi
done

phase "Installing oh-my-zsh (unattended)"
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

phase "Running linker.sh, answering y to every prompt"
# linker.sh reads single keypresses (read -n 1), so send y's with no newlines.
# The input is finite on purpose: an endless `yes` kept the pipeline running
# after linker.sh exited. Homebrew also swallows some of it, hence the size.
cd "$repo"
set +eo pipefail
perl -e 'print "y" x 100000' | with_time_limit 1800 ./linker.sh
status=${PIPESTATUS[1]}
phase "linker.sh exit status: $status"
exit "$status"
