#!/usr/bin/env bash
# Tests tools/mac-inventory.sh on the baseline Mac: runs it with the stock
# macOS bash 3.2, checks that it redacts secrets, and that it changes no files.
set -euo pipefail
out="${1:?usage: test-mac-inventory.sh OUTPUT_DIR}"
mkdir -p "$out"
script="$PWD/tools/mac-inventory.sh"

# Fake secrets in a settings file. ~/.claude is a symlink into the old repo,
# as on a Mac set up with linker.sh.
cat > "$HOME/.claude/settings.local.json" <<'JSON'
{
  "model": "opus",
  "env": {
    "GITHUB_TOKEN": "ghp_FAKEsecret1234567890abcdefghijklmnop",
    "SOME_SETTING": "plain-value"
  },
  "apiKeyHelper": "sk-ant-FAKEsecret0987654321",
  "randomBlob": "a8f3k2j9d0s8f7g6h5j4k3l2m1n0b9v8c7x6",
  "permissions": { "allow": ["Bash(git status:*)"] }
}
JSON

marker="$RUNNER_TEMP/inventory-marker"
touch "$marker"
sleep 1

/bin/bash --version | head -1
status=0
/bin/bash "$script" > "$out/mac-inventory.txt" 2> "$out/mac-inventory-stderr.txt" || status=$?
echo "inventory exit status: $status"

failed=0
[[ $status -eq 0 ]] || failed=1
for secret in ghp_FAKEsecret sk-ant-FAKEsecret a8f3k2j9d0s8f7g6; do
  if grep -q "$secret" "$out/mac-inventory.txt"; then echo "ERROR: secret leaked: $secret"; failed=1; fi
done
for expected in '"model": "opus"' '"SOME_SETTING": "plain-value"' 'Bash(git status:*)' '[REDACTED]' \
                '.claude: symlink ->' '# End of inventory'; do
  grep -qF "$expected" "$out/mac-inventory.txt" || { echo "ERROR: missing from output: $expected"; failed=1; }
done
if [[ -s "$out/mac-inventory-stderr.txt" ]]; then
  echo "ERROR: inventory wrote to stderr:"; cat "$out/mac-inventory-stderr.txt"; failed=1
fi

# Read-only check: nothing under ~ or /usr/local/bin may change, except caches
# in ~/Library and the GitHub runner's own directories.
changed=$(find "$HOME" \( -path "$HOME/Library" -o -path "$HOME/work" -o -path "$HOME/actions-runner" \) -prune -o -newer "$marker" -print 2>/dev/null || true)
changed+=$(find /usr/local/bin -newer "$marker" -print 2>/dev/null || true)
if [[ -n "$changed" ]]; then
  echo "ERROR: inventory changed files:"; echo "$changed"; failed=1
else
  echo "Read-only check passed: no files changed."
fi

echo "---- inventory output ----"
cat "$out/mac-inventory.txt"
exit "$failed"
