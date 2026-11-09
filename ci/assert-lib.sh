# Shared checks for the CI scenarios. Sourced, not run.
failures=0
check() { # description command...
  local what="$1"; shift
  local err; err=$(mktemp)
  if "$@" > /dev/null 2> "$err"; then echo "PASS: $what"
  else echo "FAIL: $what"; sed 's/^/    /' "$err" | head -30; failures=$((failures + 1)); fi
}
links_into_old_repo() {
  { find "$HOME" -maxdepth 3 \( -path "$HOME/Library" -o -path "$HOME/src" -o -path "$HOME/.dotfiles-migration" \
      -o -path "$HOME/work" -o -path "$HOME/actions-runner" \) -prune -o -type l -print 2>/dev/null
    ls -d /usr/local/bin/* 2>/dev/null; } |
  while IFS= read -r l; do [[ -L "$l" && "$(readlink "$l")" == "$HOME/src/dotfiles/"* ]] && echo "$l"; done
}
no_links_into_old_repo() { [[ -z "$(links_into_old_repo)" ]]; }
seeded_data_intact() { (cd "$HOME" && shasum -a 256 -c --quiet "$1"); }
same_file() { cmp -s "$1" "$2"; }
old_repo_unchanged() { # before-snapshot-dir
  local now; now=$(mktemp)
  (cd "$HOME/src/dotfiles" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 shasum -a 256) > "$now"
  cmp -s "$1/repo-checksums.txt" "$now" || { diff "$1/repo-checksums.txt" "$now" | head; return 1; }
}
# Checksums (or link targets) of every file chezmoi manages. Scanning all of ~
# would catch unrelated background activity, such as macOS creating ~/Movies/TV.
tree_list() {
  chezmoi managed --include files,symlinks --path-style absolute < /dev/null | LC_ALL=C sort | while IFS= read -r p; do
    if [[ -L "$p" ]]; then echo "link $(readlink "$p") $p"
    elif [[ -f "$p" ]]; then echo "$(shasum -a 256 < "$p" | cut -d' ' -f1) $p"
    else echo "missing $p"; fi
  done
}
idempotent_apply() {
  local before after status
  before=$(mktemp); after=$(mktemp)
  tree_list > "$before"
  chezmoi apply < /dev/null || { echo "  chezmoi apply failed" >&2; return 1; }
  tree_list > "$after"
  status=$(chezmoi status < /dev/null)
  if ! cmp -s "$before" "$after"; then echo "  files changed by a second apply:" >&2; diff "$before" "$after" | head -20 >&2; return 1; fi
  if [[ -n "$status" ]]; then echo "  chezmoi status after a second apply:" >&2; echo "$status" >&2; return 1; fi
}
zsh_ok() { perl -e 'alarm 90; exec @ARGV' zsh -i -c "$1" < /dev/null; }
finish() { echo "$failures check(s) failed."; exit $(( failures > 0 )); }
