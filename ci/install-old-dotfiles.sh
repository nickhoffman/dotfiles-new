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

repo="$HOME/src/dotfiles"
git clone https://github.com/nickhoffman/dotfiles "$repo"
git -C "$repo" checkout --quiet "$OLD_DOTFILES_SHA"

# linker.sh requires a writable /usr/local/bin.
sudo mkdir -p /usr/local/bin
sudo chown "$(id -un)" /usr/local/bin

echo "### Installing oh-my-zsh (unattended)"
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "### Running linker.sh, answering y to every prompt"
# linker.sh reads single keypresses (read -n 1), so send y's with no newlines.
cd "$repo"
set +eo pipefail
yes y | tr -d '\n' | ./linker.sh
status=${PIPESTATUS[2]}
echo "linker.sh exit status: $status"
exit "$status"
