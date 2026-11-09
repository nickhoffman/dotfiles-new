# dotfiles-new

My dotfiles, managed with [chezmoi](https://www.chezmoi.io/). They replace
[nickhoffman/dotfiles](https://github.com/nickhoffman/dotfiles) and its `linker.sh`.

## Machine profiles

Every machine has one profile, saved by `chezmoi init`:

| Profile    | Machine          | Gets |
|------------|------------------|------|
| `personal` | personal Mac     | everything, plus `Brewfile.personal` |
| `work`     | work Mac         | everything, plus `Brewfile.work` and the work-only app preferences |
| `devbox`   | Linux devbox     | a minimal subset: tmux, vim, git, Claude Code, shell aliases for bash |

The profile comes from `$DOTFILES_PROFILE`, else the saved value, else a prompt.
With no terminal and no profile, `chezmoi init` fails with an error instead of
hanging.

## Set up a machine

**Devbox** (unattended, no terminal needed):

```sh
DOTFILES_PROFILE=devbox sh -c "$(curl -fsLS --retry 5 --retry-all-errors get.chezmoi.io)" -- -b ~/.local/bin init --apply nickhoffman/dotfiles-new
```

In a devbox init script, retry it: the chezmoi download inside that script
doesn't retry on its own, and GitHub sometimes returns HTTP 504. Re-running is
safe.

```sh
for attempt in 1 2 3; do
  DOTFILES_PROFILE=devbox sh -c "$(curl -fsLS --retry 5 --retry-all-errors get.chezmoi.io)" -- -b ~/.local/bin init --apply nickhoffman/dotfiles-new && break
  sleep 10
done
```

**New Mac:** install [Homebrew](https://brew.sh), then:

```sh
brew install chezmoi
DOTFILES_PROFILE=personal chezmoi init --apply --source ~/src/dotfiles-new nickhoffman/dotfiles-new
```

**Mac that uses the old `linker.sh` dotfiles:** see [Migrating a Mac](#migrating-a-mac).

## Migrating a Mac

`tools/migrate-mac.sh` moves a Mac from `~/src/dotfiles` to this repo:

1. Make a Time Machine backup.
2. Quit Claude Code and Alfred.
3. Run:

   ```sh
   git clone https://github.com/nickhoffman/dotfiles-new ~/src/dotfiles-new
   ~/src/dotfiles-new/tools/migrate-mac.sh --profile personal   # or work
   ```

It shows what it found and asks you to type `yes` before changing anything.
Then it:

- backs up `~/src/dotfiles` to a tarball;
- replaces each symlink into `~/src/dotfiles` (in `~` and `/usr/local/bin`)
  with a copy of its target, checked file by file before it's swapped in;
- moves Alfred's sync folder to `~/src/dotfiles-new/alfred`;
- refuses to continue, and rolls back, if chezmoi would overwrite a file
  that was edited locally on this Mac;
- applies the dotfiles, verifies them, then runs the install scripts
  (Homebrew packages, oh-my-zsh, asdf and Ruby, app preferences).

`~/src/dotfiles` itself is never changed. State, backups and a log go to
`~/.dotfiles-migration/<timestamp>/`.

To undo it: `~/src/dotfiles-new/tools/migrate-mac.sh --rollback`. Rollback
restores the old symlinks and moves the migrated files aside into the state
directory; it never deletes anything.

## Layout

- `home/` is chezmoi's source directory (see `.chezmoiroot`).
  - `.chezmoi.toml.tmpl` picks the profile.
  - `.chezmoiignore` decides which files each machine gets.
  - `.chezmoiscripts/` installs packages and tools.
  - `.chezmoidata/claude-settings.json` lists the Claude Code settings each
    profile owns. Other keys in `~/.claude/settings.json` are left alone.
  - `.brew/` holds the Brewfiles; `.mac-app-preferences/` holds app plists.
- `alfred/` is Alfred's sync folder.
- `tools/` has the migration script, the read-only Mac inventory script and
  `export-mac-app-preferences.sh`.
- `ci/` has the CI test scenarios.

## Common changes

- **App on one Mac only:** add it to `home/.brew/Brewfile.personal` or `Brewfile.work`.
- **Setting that differs by machine:** use a `.tmpl` file with `{{ if eq .profile "work" }}`.
- **Claude Code setting for one machine:** add the key under that profile in
  `home/.chezmoidata/claude-settings.json`.
- **Save app preferences:** `tools/export-mac-app-preferences.sh`, then commit.

## Tests

`.github/workflows/test.yml` runs on every push:

- On macOS runners, it rebuilds the old `linker.sh` setup (modelled on the
  personal Mac, with fake app data) and tests migration, rollback, and refusal
  on a local edit, for both profiles. It also sets up a brand-new Mac.
- In an Ubuntu container with no terminal, it runs the devbox one-liner.
