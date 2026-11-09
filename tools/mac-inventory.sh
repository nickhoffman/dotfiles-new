#!/bin/bash
# Read-only inventory of a Mac set up with the old linker.sh dotfiles.
#
# Prints what the chezmoi migration needs to know about this Mac: which paths
# are symlinks into the old repo, what untracked data lives inside the repo,
# installed apps and packages, and Claude Code settings with secret-looking
# values redacted. It creates, changes and deletes nothing.
#
# Usage:  bash mac-inventory.sh [OLD_REPO] > ~/Desktop/mac-inventory.txt
#         (OLD_REPO defaults to ~/src/dotfiles)
#
# Review the output before sharing it.
#
# Written for the bash 3.2 and tools that ship with macOS.

set -u
repo="${1:-$HOME/src/dotfiles}"

section() { printf '\n## %s\n' "$*"; }
have() { command -v "$1" > /dev/null 2>&1; }

echo "# Mac inventory"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Old repo: $repo"

section "System"
sw_vers 2>&1
echo "Architecture: $(uname -m)"
echo "Login shell: ${SHELL:-unknown}"

section "Old repo state"
if [[ -d "$repo/.git" ]]; then
  echo "HEAD: $(git -C "$repo" rev-parse HEAD 2>&1)"
  echo "Branch: $(git -C "$repo" rev-parse --abbrev-ref HEAD 2>&1)"
  echo "Remote: $(git -C "$repo" remote get-url origin 2>&1)"
  echo "Commits not on the remote branch:"
  git -C "$repo" log --oneline '@{upstream}..HEAD' 2>&1 | sed 's/^/  /'
  echo "Tracked files with local changes (names and line counts only):"
  git -C "$repo" diff --stat HEAD 2>&1 | sed 's/^/  /'
  echo "Untracked files not ignored:"
  git -C "$repo" ls-files --others --exclude-standard 2>&1 | sed 's/^/  /'
else
  echo "ERROR: $repo is not a git repository."
fi

section "Ignored data inside the old repo (sizes only)"
# This is where app data lands when a whole directory is symlinked into the repo.
if [[ -d "$repo/.git" ]]; then
  git -C "$repo" ls-files --others --ignored --exclude-standard --directory 2>/dev/null |
    while IFS= read -r p; do
      printf '  %8s  %s\n' "$(du -sh "$repo/$p" 2>/dev/null | cut -f1)" "$p"
    done
fi

section "How each entry of the old repo's home/ appears in ~"
for f in "$repo"/home/.[!.]*; do
  [[ -e "$f" || -L "$f" ]] || continue
  b=$(basename "$f"); t="$HOME/$b"
  if   [[ -L "$t" ]]; then echo "  $b: symlink -> $(readlink "$t")"
  elif [[ -d "$t" ]]; then echo "  $b: real directory"
  elif [[ -e "$t" ]]; then echo "  $b: real file"
  else                     echo "  $b: missing"
  fi
done

section "All symlinks under ~ (3 levels deep, excluding ~/Library) that point into the old repo"
find "$HOME" -maxdepth 3 \( -path "$HOME/Library" -o -path "$HOME/.Trash" \) -prune -o -type l -print 2>/dev/null |
  while IFS= read -r l; do
    target=$(readlink "$l")
    case "$target" in *"$repo"*|*dotfiles*) echo "  ${l#"$HOME"/} -> $target" ;; esac
  done

section "~/.config"
if [[ -L "$HOME/.config" ]]; then
  echo "~/.config is a symlink -> $(readlink "$HOME/.config")"
elif [[ -d "$HOME/.config" ]]; then
  echo "~/.config is a real directory. Entries:"
  for e in "$HOME"/.config/* "$HOME"/.config/.[!.]*; do
    [[ -e "$e" || -L "$e" ]] || continue
    if [[ -L "$e" ]]; then echo "  $(basename "$e") -> $(readlink "$e")"
    else echo "  $(basename "$e")"
    fi
  done
else
  echo "~/.config does not exist."
fi

section "~/.claude"
if [[ -L "$HOME/.claude" ]]; then
  echo "~/.claude is a symlink -> $(readlink "$HOME/.claude")"
elif [[ -d "$HOME/.claude" ]]; then
  echo "~/.claude is a real directory."
fi
if [[ -d "$HOME/.claude" ]]; then
  echo "Top-level entries and sizes:"
  for e in "$HOME"/.claude/* "$HOME"/.claude/.[!.]*; do
    [[ -e "$e" || -L "$e" ]] || continue
    kind=""; [[ -L "$e" ]] && kind=" -> $(readlink "$e")"
    printf '  %8s  %s%s\n' "$(du -sh "$e" 2>/dev/null | cut -f1)" "$(basename "$e")" "$kind"
  done
fi

section "Symlinks in /usr/local/bin that point into the old repo"
for l in /usr/local/bin/*; do
  [[ -L "$l" ]] || continue
  target=$(readlink "$l")
  case "$target" in *"$repo"*|*dotfiles*) echo "  $(basename "$l") -> $target" ;; esac
done

section "Other local or per-machine config files in ~"
for f in "$HOME"/.*.local "$HOME"/.*local* "$HOME"/.*work* "$HOME"/.zshenv "$HOME"/.bashrc "$HOME"/.bash_profile "$HOME"/.profile; do
  [[ -e "$f" ]] && echo "  ${f#"$HOME"/}"
done | sort -u
echo "Include and source lines in shell and git config (paths only):"
for f in "$HOME"/.zshrc "$HOME"/.zprofile "$HOME"/.gitconfig; do
  [[ -e "$f" ]] || continue
  grep -nE '^\s*(source|\.|\[include|\[includeIf|path\s*=)' "$f" 2>/dev/null | sed "s|^|  $(basename "$f"):|"
done

section "Apps"
echo "/Applications:"
ls -1 /Applications 2>/dev/null | sed 's/^/  /'
if [[ -d "$HOME/Applications" ]]; then
  echo "~/Applications:"
  ls -1 "$HOME/Applications" 2>/dev/null | sed 's/^/  /'
fi

section "Homebrew"
if have brew; then
  # HOMEBREW_NO_AUTO_UPDATE keeps brew from updating itself while being inspected.
  export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1
  echo "Prefix: $(brew --prefix)"
  brew --version 2>&1 | head -1
  echo "Taps:";             brew tap 2>&1 | sed 's/^/  /'
  echo "Formulae (leaves):"; brew leaves 2>&1 | sed 's/^/  /'
  echo "Casks:";            brew list --cask -1 2>&1 | sed 's/^/  /'
else
  echo "brew not found on PATH."
fi

section "Version managers and languages"
if have asdf; then
  echo "asdf: $(asdf --version 2>&1 | head -1)"
  echo "asdf plugins:"; asdf plugin list 2>&1 | sed 's/^/  /'
  echo "asdf current:"; (cd "$HOME" && asdf current 2>&1) | sed 's/^/  /'
else
  echo "asdf not found on PATH."
fi
for t in ruby node; do
  if have "$t"; then echo "$t: $(command -v "$t") ($("$t" --version 2>&1 | head -1))"; fi
done
[[ -d "$HOME/.oh-my-zsh" ]] && echo "oh-my-zsh: installed" || echo "oh-my-zsh: not installed"

section "App preference domains the old repo imports"
for d in com.googlecode.iterm2 com.knollsoft.Rectangle com.lwouis.alt-tab-macos \
         com.runningwithcrayons.Alfred-Preferences com.stripe.jil.meetingbar \
         com.surteesstudios.Bartender pl.maketheweb.cleanshotx; do
  if defaults read "$d" > /dev/null 2>&1; then echo "  $d: present"; else echo "  $d: absent"; fi
done

section "Claude Code settings (secret-looking values redacted)"
# Uses JavaScript for Automation, which ships with macOS, to parse the JSON.
redact_json() {
  /usr/bin/osascript -l JavaScript - "$1" <<'JXA'
function run(argv) {
  ObjC.import("Foundation");
  const text = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null);
  if (text.isNil()) return "(could not read)";
  let data;
  try { data = JSON.parse(text.js); } catch (e) { return "(invalid JSON: " + e + ")"; }
  const secretKey = /(token|secret|passw|api[_-]?key|auth|credential|cookie|session|private)/i;
  const secretValue = /^(sk-|ghp_|gho_|github_pat_|xox[abposr]-|AKIA|eyJ|op:\/\/)/;
  function looksRandom(s) {
    return s.length >= 32 && !/\s/.test(s) && !/^[\/~.]/.test(s) && !/[()*]/.test(s) &&
           /[0-9]/.test(s) && /[A-Za-z]/.test(s);
  }
  function redact(value, key) {
    if (Array.isArray(value)) return value.map(v => redact(v, key));
    if (value && typeof value === "object") {
      const out = {};
      for (const k of Object.keys(value)) out[k] = redact(value[k], k);
      return out;
    }
    if (typeof value === "string" &&
        ((key && secretKey.test(key)) || secretValue.test(value) || looksRandom(value))) {
      return "[REDACTED]";
    }
    return value;
  }
  return JSON.stringify(redact(data, null), null, 2);
}
JXA
}
for f in "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json"; do
  echo "### ${f#"$HOME"/}"
  if [[ -L "$f" ]]; then echo "(symlink -> $(readlink "$f"))"; fi
  if [[ -f "$f" ]]; then redact_json "$f"; else echo "(does not exist)"; fi
done

echo
echo "# End of inventory"
