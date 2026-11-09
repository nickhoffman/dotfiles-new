#!/bin/bash
# Migrates a Mac from the old linker.sh dotfiles (~/src/dotfiles) to chezmoi
# (~/src/dotfiles-new), and rolls the migration back.
#
#   migrate-mac.sh [--profile personal|work] [--yes]
#   migrate-mac.sh --rollback [STATE_DIR]
#
# Options:
#   --profile NAME   Machine profile. Default: $DOTFILES_PROFILE, else asks.
#   --old-repo DIR   Default: ~/src/dotfiles
#   --new-repo DIR   Default: ~/src/dotfiles-new (cloned from GitHub if missing)
#   --yes            Don't ask for confirmation.
#   --rollback [DIR] Undo a migration. DIR defaults to the newest state dir.
#
# Safety rules:
# - Nothing in the old repo is changed or deleted. It stays as the rollback.
# - Each symlink into the old repo is replaced by a verified copy of its
#   target. The symlink itself is moved into the state dir, not deleted.
# - Before chezmoi changes an existing file, the file must match the old
#   repo's committed version (an intended update). A local edit stops the
#   migration and rolls back.
# - Any failure before the files are verified rolls back automatically.
# - Rollback moves things aside into the state dir. It never deletes.
#
# State, backups and a log go to ~/.dotfiles-migration/<timestamp>/.
#
# Written for the bash 3.2 and tools that ship with macOS.

set -uo pipefail

old_repo="$HOME/src/dotfiles"
new_repo="$HOME/src/dotfiles-new"
new_repo_url="https://github.com/nickhoffman/dotfiles-new.git"
profile="${DOTFILES_PROFILE:-}"
assume_yes=0
mode=migrate
rollback_dir=""
state_root="$HOME/.dotfiles-migration"

# Old-repo entries the new setup doesn't deploy. Their links are removed
# (moved into the state dir) instead of being replaced by copies.
retired_links=".homebrew_packages_to_install .ruby_gems_to_install"

# Third-party plugin files chezmoi may replace even if they differ.
replaceable_prefixes=".vim/bundle/vim-prettier/ .vim/bundle/vim-graphql/"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)  profile="$2"; shift 2 ;;
    --old-repo) old_repo="$2"; shift 2 ;;
    --new-repo) new_repo="$2"; shift 2 ;;
    --yes)      assume_yes=1; shift ;;
    --rollback) mode=rollback; shift
                if [[ $# -gt 0 && "$1" != --* ]]; then rollback_dir="$1"; shift; fi ;;
    -h|--help)  sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

state=""
log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "${state:-/dev/null}/log.txt" >&2; }
die() { log "ERROR: $*"; exit 1; }
sha() { shasum -a 256 < "$1" | cut -d' ' -f1; }

# Lists regular files (with checksums) and symlinks (with targets) under a
# directory, skipping git's submodule pointer files. Used to verify copies.
tree_manifest() {
  (
    cd "$1" || exit 1
    find . -type f ! -name .git -print0 | xargs -0 shasum -a 256 2>/dev/null | awk '{h=$1; $1=""; print "f" h $0}'
    find . -type l -print | while IFS= read -r l; do printf 'l %s -> %s\n' "$l" "$(readlink "$l")"; done
  ) | LC_ALL=C sort
}

# Symlinks under ~ (and in /usr/local/bin) that point into the old repo.
find_old_links() {
  {
    find "$HOME" -maxdepth 3 \( -path "$HOME/Library" -o -path "$HOME/.Trash" -o -path "$old_repo" \
      -o -path "$new_repo" -o -path "$state_root" \) -prune -o -type l -print 2>/dev/null
    for l in /usr/local/bin/*; do [[ -L "$l" ]] && echo "$l"; done
  } | while IFS= read -r l; do
    t=$(readlink "$l")
    [[ "$t" == /* ]] || t="$(dirname "$l")/$t"
    case "$t" in "$old_repo"/*) printf '%s\t%s\n' "$l" "$t" ;; esac
  done | LC_ALL=C sort
}

# Where a path is stashed inside the state dir.
stash_path() { # kind path
  local p="$2"
  case "$p" in
    "$HOME"/*) echo "$state/$1/home/${p#"$HOME"/}" ;;
    *)         echo "$state/$1/abs$p" ;;
  esac
}

stash() { # kind path: moves path into the state dir
  local dest; dest=$(stash_path "$1" "$2")
  mkdir -p "$(dirname "$dest")" && mv "$2" "$dest"
}

######## Rollback ########

rollback() {
  [[ -d "$state" ]] || die "No state dir to roll back: $state"
  [[ -f "$state/ROLLED_BACK" ]] && die "Already rolled back: $state"
  log "Rolling back using $state"
  local failed=0 kind path target stashed

  # Files chezmoi created. Moved aside.
  if [[ -f "$state/added.txt" ]]; then
    while IFS= read -r path; do
      [[ -e "$path" || -L "$path" ]] || continue
      stash rollback-added "$path" && log "Moved aside chezmoi-created $path" || failed=1
    done < "$state/added.txt"
  fi

  # Existing real files chezmoi changed (outside any replaced link). Restored.
  if [[ -f "$state/modified.txt" ]]; then
    while IFS= read -r path; do
      stashed=$(stash_path modified "$path")
      [[ -e "$stashed" ]] || continue
      [[ -e "$path" ]] && { stash rollback-modified "$path" || failed=1; }
      mv "$stashed" "$path" && log "Restored $path" || failed=1
    done < "$state/modified.txt"
  fi

  # Symlinks, newest action first.
  if [[ -f "$state/links.tsv" ]]; then
    tail -r "$state/links.tsv" | while IFS=$'\t' read -r kind path target; do
      stashed=$(stash_path links "$path")
      if [[ -e "$path.dotfiles-migration-tmp" ]]; then   # an unfinished copy
        stash rollback-partial "$path.dotfiles-migration-tmp" || { log "ERROR: could not move aside $path.dotfiles-migration-tmp"; exit 1; }
      fi
      if [[ -L "$path" && "$(readlink "$path")" == "$target" ]]; then continue; fi
      if [[ -e "$path" || -L "$path" ]]; then
        stash rollback-migrated "$path" || { log "ERROR: could not move aside $path"; exit 1; }
      fi
      if [[ -L "$stashed" ]]; then
        mkdir -p "$(dirname "$path")" && mv "$stashed" "$path" && log "Restored link $path -> $target" \
          || { log "ERROR: could not restore $path"; exit 1; }
      else
        ln -s "$target" "$path" && log "Recreated link $path -> $target" || { log "ERROR: could not recreate $path"; exit 1; }
      fi
    done || failed=1
  fi

  # Alfred's sync folder.
  if [[ -f "$state/alfred-syncfolder.txt" ]]; then
    defaults write com.runningwithcrayons.Alfred-Preferences syncfolder "$(cat "$state/alfred-syncfolder.txt")" \
      && log "Restored Alfred's sync folder" || failed=1
    if [[ -d "$(stash_path alfred "$new_repo/alfred/Alfred.alfredpreferences")" ]]; then
      stash rollback-alfred "$new_repo/alfred/Alfred.alfredpreferences" 2>/dev/null
      mv "$(stash_path alfred "$new_repo/alfred/Alfred.alfredpreferences")" "$new_repo/alfred/Alfred.alfredpreferences" || failed=1
    fi
  fi

  # Check every link is back.
  if [[ -f "$state/links.tsv" ]]; then
    while IFS=$'\t' read -r kind path target; do
      [[ -L "$path" && "$(readlink "$path")" == "$target" ]] || { log "ERROR: $path is not restored"; failed=1; }
    done < "$state/links.tsv"
  fi

  if [[ $failed -eq 0 ]]; then
    date > "$state/ROLLED_BACK"
    log "Rollback complete. The old setup is back. Moved-aside files are in $state."
  else
    log "Rollback finished with errors. Nothing was deleted; see $state/log.txt."
  fi
  return $failed
}

if [[ $mode == rollback ]]; then
  if [[ -z "$rollback_dir" ]]; then
    rollback_dir=$(ls -1d "$state_root"/*/ 2>/dev/null | tail -1)
    rollback_dir="${rollback_dir%/}"
  fi
  state="$rollback_dir"
  rollback; exit $?
fi

######## Migration ########

[[ "$(uname)" == Darwin ]] || { echo "This script is for macOS." >&2; exit 1; }
[[ $(id -u) -ne 0 ]] || { echo "Don't run this as root." >&2; exit 1; }

state="$state_root/$(date '+%Y%m%d-%H%M%S')"
mkdir -p "$state" || exit 1
log "Migration state, backups and log: $state"

for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [[ -x $b ]] && eval "$("$b" shellenv)" && break; done
export HOMEBREW_NO_AUTO_UPDATE=1

### Preflight (read-only)
log "Preflight checks"
[[ -d "$old_repo/.git" ]] || die "Old repo not found at $old_repo"
old_repo=$(cd "$old_repo" && pwd)
command -v brew > /dev/null || die "Homebrew is required."
for d in "$state_root"/*/; do
  [[ -f "$d/DONE" && ! -f "$d/ROLLED_BACK" ]] && die "This Mac was already migrated (see $d). Roll that back first."
done
[[ -e "$HOME/.config/chezmoi" ]] && die "~/.config/chezmoi already exists, so chezmoi is already set up here."
pgrep -x claude > /dev/null && die "Claude Code is running. Quit every Claude Code session, then re-run."
alfred_sync=$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder 2>/dev/null || true)
alfred_sync_abs="${alfred_sync/#\~/$HOME}"
alfred_moves=0
case "$alfred_sync_abs" in
  "$old_repo"/*)
    alfred_moves=1
    pgrep -x Alfred > /dev/null && die "Alfred is running and syncs into the old repo. Quit Alfred, then re-run." ;;
esac

find_old_links > "$state/links-found.tsv"
link_count=$(wc -l < "$state/links-found.tsv" | tr -d ' ')
[[ $link_count -gt 0 ]] || die "No symlinks into $old_repo found. Nothing to migrate."

if [[ -z "$profile" ]]; then
  [[ -t 0 ]] || die "No profile. Pass --profile personal|work."
  read -r -p "Machine profile (personal/work): " profile
fi
case "$profile" in personal|work) ;; *) die "Profile must be personal or work, not '$profile'." ;; esac

need_kb=$(du -sk "$old_repo" | cut -f1)
free_kb=$(df -k "$HOME" | awk 'NR==2 {print $4}')
[[ $free_kb -gt $(( need_kb * 3 + 1048576 )) ]] || die "Not enough free disk space (need about $(( need_kb * 3 / 1024 + 1024 )) MB)."

log "Profile: $profile"
log "Found $link_count symlinks into the old repo:"
while IFS=$'\t' read -r l t; do log "  $l -> $t"; done < "$state/links-found.tsv"
[[ $alfred_moves -eq 1 ]] && log "Alfred's sync folder will move from $alfred_sync to ~/src/dotfiles-new/alfred"

if [[ $assume_yes -ne 1 ]]; then
  [[ -t 0 ]] || die "Pass --yes to run without a terminal."
  read -r -p "Type yes to migrate: " answer
  [[ "$answer" == yes ]] || die "Not confirmed. Nothing was changed."
fi

# From here on, a failure rolls back.
fail() { log "ERROR: $*"; log "Rolling back automatically."; rollback; exit 1; }

### Backups
log "Backing up the old repo to $state/old-repo.tar.gz"
if ! tar -czf "$state/old-repo.tar.gz" -C "$(dirname "$old_repo")" "$(basename "$old_repo")" 2> "$state/tar-errors.txt"; then
  # Sockets can't be archived; anything else is a real failure.
  if grep -iv 'socket' "$state/tar-errors.txt" | grep -q .; then
    fail "Backup failed: $(head -3 "$state/tar-errors.txt")"
  fi
fi
defaults export com.runningwithcrayons.Alfred-Preferences "$state/alfred-preferences.plist" 2>/dev/null || true

### New repo and chezmoi
if [[ ! -d "$new_repo/.git" ]]; then
  log "Cloning $new_repo_url to $new_repo"
  mkdir -p "$(dirname "$new_repo")"
  git clone --quiet "$new_repo_url" "$new_repo" || fail "Could not clone the new repo."
fi
if ! command -v chezmoi > /dev/null; then
  log "Installing chezmoi with Homebrew"
  brew install chezmoi > "$state/brew-chezmoi.txt" 2>&1 || fail "Could not install chezmoi."
fi

### Replace each symlink with a verified copy of its target
: > "$state/links.tsv"
while IFS=$'\t' read -r link target; do
  name=$(basename "$link")
  case " $retired_links " in
    *" $name "*)
      printf 'removed\t%s\t%s\n' "$link" "$target" >> "$state/links.tsv"
      stash links "$link" || fail "Could not move $link"
      log "Removed retired link $link"
      continue ;;
  esac
  case "$link" in
    /usr/local/bin/*)
      printf 'removed\t%s\t%s\n' "$link" "$target" >> "$state/links.tsv"
      stash links "$link" || fail "Could not move $link (is /usr/local/bin writable?)"
      log "Removed $link (now in ~/.local/bin)"
      continue ;;
  esac
  if [[ ! -e "$target" ]]; then
    printf 'removed\t%s\t%s\n' "$link" "$target" >> "$state/links.tsv"
    stash links "$link" || fail "Could not move $link"
    log "Removed broken link $link"
    continue
  fi

  tmp="$link.dotfiles-migration-tmp"
  [[ -e "$tmp" ]] && fail "$tmp already exists."
  printf 'copied\t%s\t%s\n' "$link" "$target" >> "$state/links.tsv"
  if [[ -d "$target" ]]; then
    # cp can't copy sockets; the manifest check below decides if the copy is good.
    cp -pPR "$target" "$tmp" 2>> "$state/cp-errors.txt" || true
    find "$tmp" -name .git -type f -delete 2>/dev/null   # submodule pointers into the old repo's .git
    tree_manifest "$target" > "$state/manifest-src.txt"
    tree_manifest "$tmp" > "$state/manifest-copy.txt"
    if ! cmp -s "$state/manifest-src.txt" "$state/manifest-copy.txt"; then
      diff "$state/manifest-src.txt" "$state/manifest-copy.txt" | head -20 >> "$state/log.txt"
      fail "Copy of $target doesn't match the original."
    fi
    count=$(wc -l < "$state/manifest-src.txt" | tr -d ' ')
  else
    cp -pP "$target" "$tmp" || fail "Could not copy $target"
    [[ "$(sha "$target")" == "$(sha "$tmp")" ]] || fail "Copy of $target doesn't match the original."
    count=1
  fi
  stash links "$link" || fail "Could not move $link"
  mv "$tmp" "$link" || fail "Could not move the copy into place at $link"
  log "Replaced link $link with a verified copy ($count entries)"
done < "$state/links-found.tsv"

### Alfred's sync folder
if [[ $alfred_moves -eq 1 ]]; then
  src="$alfred_sync_abs/Alfred.alfredpreferences"
  dest="$new_repo/alfred/Alfred.alfredpreferences"
  if [[ -d "$src" ]]; then
    printf '%s' "$alfred_sync" > "$state/alfred-syncfolder.txt"
    [[ -d "$dest" ]] && { stash alfred "$dest" || fail "Could not move aside $dest"; }
    mkdir -p "$(dirname "$dest")"
    cp -pPR "$src" "$dest" || fail "Could not copy Alfred's preferences"
    cmp -s <(tree_manifest "$src") <(tree_manifest "$dest") || fail "Copy of Alfred's preferences doesn't match."
    defaults write com.runningwithcrayons.Alfred-Preferences syncfolder "~/src/dotfiles-new/alfred" \
      || fail "Could not change Alfred's sync folder"
    log "Moved Alfred's sync folder to ~/src/dotfiles-new/alfred"
  fi
fi

### chezmoi init
log "Running chezmoi init (profile $profile)"
DOTFILES_PROFILE="$profile" chezmoi init --source "$new_repo" < /dev/null > "$state/chezmoi-init.txt" 2>&1 \
  || fail "chezmoi init failed: $(tail -3 "$state/chezmoi-init.txt")"

### Check every change chezmoi would make
log "Checking the changes chezmoi would make"
chezmoi status --exclude scripts < /dev/null > "$state/chezmoi-status.txt" 2>&1 || fail "chezmoi status failed: $(tail -3 "$state/chezmoi-status.txt")"
: > "$state/added.txt"; : > "$state/modified.txt"; : > "$state/unexpected.txt"
while IFS= read -r line; do
  code="${line:1:1}"; rel="${line:3}"; path="$HOME/$rel"
  case "$code" in
    A) echo "$path" >> "$state/added.txt" ;;
    M)
      ok=0
      for prefix in $replaceable_prefixes; do case "$rel" in "$prefix"*) ok=1 ;; esac; done
      if [[ $ok -eq 0 ]] && git -C "$old_repo" cat-file -e "HEAD:home/$rel" 2>/dev/null; then
        committed=$(git -C "$old_repo" show "HEAD:home/$rel" | shasum -a 256 | cut -d' ' -f1)
        [[ -f "$path" && "$(sha "$path")" == "$committed" ]] && ok=1
      fi
      if [[ $ok -eq 1 ]]; then echo "$path" >> "$state/modified.txt"; else echo "$rel" >> "$state/unexpected.txt"; fi ;;
    " ") ;;
    *) echo "$rel ($code)" >> "$state/unexpected.txt" ;;
  esac
done < "$state/chezmoi-status.txt"
if [[ -s "$state/unexpected.txt" ]]; then
  while IFS= read -r rel; do chezmoi diff "$HOME/${rel%% (*}" < /dev/null >> "$state/unexpected-diff.txt" 2>&1; done < "$state/unexpected.txt"
  log "These files differ from both the old repo's committed version and the new repo:"
  while IFS= read -r rel; do log "  ~/$rel"; done < "$state/unexpected.txt"
  log "Their diffs are in $state/unexpected-diff.txt. Commit the changes you want to keep to the new repo, then re-run."
  fail "Local changes would be overwritten."
fi
log "chezmoi will add $(wc -l < "$state/added.txt" | tr -d ' ') and update $(wc -l < "$state/modified.txt" | tr -d ' ') files"

# Back up each existing file chezmoi will update.
while IFS= read -r path; do
  dest=$(stash_path modified "$path"); mkdir -p "$(dirname "$dest")"
  cp -pP "$path" "$dest" || fail "Could not back up $path"
done < "$state/modified.txt"

### Apply files, then verify
log "Applying files"
chezmoi apply --force --exclude scripts < /dev/null > "$state/chezmoi-apply-files.txt" 2>&1 \
  || fail "chezmoi apply failed: $(tail -3 "$state/chezmoi-apply-files.txt")"
chezmoi verify --exclude scripts < /dev/null > "$state/chezmoi-verify.txt" 2>&1 || fail "chezmoi verify failed after applying."
left=$(find_old_links)
[[ -z "$left" ]] || fail "Symlinks into the old repo remain: $left"
perl -e 'alarm 60; exec @ARGV' zsh -i -c 'exit 0' < /dev/null > "$state/zsh-check.txt" 2>&1 \
  || fail "A new zsh doesn't start cleanly: $(tail -3 "$state/zsh-check.txt")"
log "Files are migrated and verified."

### Install packages and tools
log "Running chezmoi's install scripts (Homebrew packages, oh-my-zsh, asdf, app preferences)"
date > "$state/DONE"
if chezmoi apply < /dev/null > "$state/chezmoi-apply-scripts.txt" 2>&1; then
  log "Install scripts finished."
else
  log "WARNING: an install script failed; see $state/chezmoi-apply-scripts.txt."
  log "Your files are migrated. Fix the problem and run: chezmoi apply"
  exit 3
fi

log "Migration complete. To undo it: $0 --rollback $state"
[[ $alfred_moves -eq 1 ]] && log "Start Alfred again; it now syncs to ~/src/dotfiles-new/alfred."
exit 0
