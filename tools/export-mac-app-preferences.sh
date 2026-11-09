#!/bin/bash
# Saves this Mac's preferences for the tracked apps into the repo, so new Macs
# get them. Replaces the old repo's `mac_app_preferences.sh export`.
#   tools/export-mac-app-preferences.sh [BUNDLE_ID ...]
set -uo pipefail
dir="$(cd "$(dirname "$0")/.." && pwd)/home/.mac-app-preferences"
ids=("$@")
if [[ ${#ids[@]} -eq 0 ]]; then
  for f in "$dir"/*.plist; do ids+=("$(basename "$f" .plist)"); done
fi
for id in "${ids[@]}"; do
  if defaults read "$id" > /dev/null 2>&1; then
    defaults export "$id" "$dir/$id.plist" && plutil -convert xml1 "$dir/$id.plist" && echo "Exported $id"
  else
    echo "Skipped $id: no preferences on this Mac"
  fi
done
