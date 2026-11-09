#!/usr/bin/env bash
# Plants fake versions of the live data the personal Mac keeps inside the old
# repo (through the ~/.config and ~/.claude symlinks), plus the repo's other
# local state. Writes a checksum manifest of every planted file, with paths
# relative to ~, so migration tests can prove each one survived.
# CI only. All values are fake.
set -euo pipefail
manifest="${1:?usage: seed-fake-data.sh MANIFEST_FILE}"
repo="$HOME/src/dotfiles"

if [[ "${CI:-}" != "true" ]]; then
  echo "Refusing to run outside CI." >&2
  exit 1
fi

[[ -L "$HOME/.claude" ]] || { echo "ERROR: ~/.claude must be a symlink into the old repo" >&2; exit 1; }

planted=()

# Writes a file through its path under ~, as the owning app would.
plant() {
  local rel="$1"; shift
  mkdir -p "$(dirname "$HOME/$rel")"
  printf '%s\n' "$@" > "$HOME/$rel"
  planted+=("$rel")
}

# Claude Code runtime data under ~/.claude.
plant .claude/projects/-Users-nick-src-app/0b9f2c1e-session.jsonl \
  '{"type":"user","message":"FAKE session line 1"}' '{"type":"assistant","message":"FAKE session line 2"}'
plant .claude/projects/-Users-nick-src-app/memory/MEMORY.md '- FAKE memory entry'
plant .claude/history.jsonl '{"display":"FAKE prompt history"}'
plant .claude/file-history/0b9f2c1e/a1b2c3@v1 'FAKE file snapshot'
plant .claude/plugins/installed_plugins.json '{"plugins":{"caveman@caveman":{"version":"FAKE"}}}'
plant .claude/plugins/cache/caveman/plugin.json '{"name":"caveman"}'
plant .claude/skills/synced/example/SKILL.md '# FAKE synced skill'
plant .claude/backups/settings.json.bak '{"FAKE":"backup"}'
plant .claude/.caveman-active 'FAKE'
plant .claude/stats-cache.json '{"FAKE":1}'
mkdir -p "$HOME"/.claude/{ssh,tmp,state,telemetry,session-env,debug}

# App data under ~/.config (inside the old repo when ~/.config is a symlink).
plant .config/gcloud/credentials.db 'FAKE gcloud credentials database'
plant .config/gcloud/configurations/config_default '[core]' 'account = fake@example.com' 'project = fake-project'
plant .config/stripe/config.toml '[default]' 'test_mode_api_key = "sk_test_FAKE0000000000000000"'
plant .config/devbox/env 'TS_AUTHKEY=tskey-FAKE' 'GH_TOKEN=github_pat_FAKE' 'REPO=FAKE'

# Finder litter and an untracked Alfred preference, as on the personal Mac.
for d in "$repo" "$repo/home" "$repo/home/.claude" "$repo/home/.config" "$repo/misc"; do
  [[ -d "$d" ]] || continue
  printf 'FAKE DS_Store\n' > "$d/.DS_Store"
done
alfred_local="$repo/misc/Alfred.alfredpreferences/preferences/local/73ce1a76e26060e47f2b0dd000b1598449deacc8/appearance"
mkdir -p "$alfred_local"
printf '<plist>FAKE</plist>\n' > "$alfred_local/prefs.plist"

# The personal Mac has no ~/.zsh link.
rm -f "$HOME/.zsh"

# Manifest of the planted data, as seen through ~.
(cd "$HOME" && shasum -a 256 "${planted[@]}") > "$manifest"
echo "Planted ${#planted[@]} files; manifest: $manifest"
