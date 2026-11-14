# CLAUDE.md

Dotfiles managed with chezmoi; see README.md for how they're used.

- `home/` is the chezmoi source directory (`.chezmoiroot`). Files outside it
  are never deployed.
- Profiles: `personal` (Mac), `work` (Mac) and `devbox` (Linux). Check every change
  against all three; `.chezmoiignore` and `.tmpl` conditionals decide what each gets.
- The Mac files were generated from nickhoffman/dotfiles at 5676c17. Keep them
  byte-identical to that commit unless a change is intended:
  `tools/migrate-mac.sh` only lets chezmoi change a file that matches the old
  repo's committed version.
- Never add app data (`~/.claude/projects`, `~/.config/gcloud`, `~/.config/stripe`,
  `~/.config/devbox/env`) to the repo. It's public.
- Don't test on a real Mac. Push and let `.github/workflows/test.yml` test on
  GitHub's macOS runners (free for this public repo).
- Scripts in `tools/` must run on stock macOS: bash 3.2, BSD tools, no Python.
