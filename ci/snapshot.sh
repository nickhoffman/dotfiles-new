#!/usr/bin/env bash
# Records the state of $HOME and the old dotfiles repo, so later runs can
# check that a migration preserved everything. Read-only.
set -uo pipefail
out="${1:?usage: snapshot.sh OUTPUT_DIR}"
repo="$HOME/src/dotfiles"
mkdir -p "$out"

{ sw_vers; uname -m; brew --version | head -1; } > "$out/system.txt" 2>&1
ls -la "$HOME" > "$out/home-listing.txt"

# How each top-level entry of the old repo's home/ ended up in ~.
for f in "$repo"/home/.[^.]*; do
  b=$(basename "$f"); t="$HOME/$b"
  if   [[ -L $t ]]; then echo "$b symlink -> $(readlink "$t")"
  elif [[ -d $t ]]; then echo "$b directory"
  elif [[ -e $t ]]; then echo "$b file"
  else                   echo "$b missing"
  fi
done > "$out/home-entries.txt"

ls -la /usr/local/bin | grep -- '->' > "$out/usr-local-bin-links.txt" || true

git -C "$repo" rev-parse HEAD > "$out/repo-head.txt"
git -C "$repo" status --porcelain --ignored > "$out/repo-status.txt"
(cd "$repo" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 shasum -a 256) > "$out/repo-checksums.txt"

brew list --formula -1 > "$out/brew-formulae.txt" 2>&1
brew list --cask -1    > "$out/brew-casks.txt" 2>&1
defaults domains | tr ',' '\n' | sed 's/^ //' | sort > "$out/defaults-domains.txt"
command -v asdf ruby > "$out/tools.txt" 2>&1; ruby --version >> "$out/tools.txt" 2>&1

# Interactive zsh must start cleanly. perl's alarm stands in for timeout(1).
perl -e 'alarm 60; exec @ARGV' zsh -i -c 'echo ZSH_STARTED_OK' < /dev/null > "$out/zsh-startup.txt" 2>&1
echo "zsh exit status: $?" >> "$out/zsh-startup.txt"
