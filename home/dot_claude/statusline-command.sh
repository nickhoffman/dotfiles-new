#!/bin/bash
# Claude Code statusline — inspired by Powerlevel10k lean prompt
# Shows: dir | git branch | model | context % | caveman badge

input=$(cat)

# --- Directory (abbreviated like p10k) ---
cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -n "$cwd" ]; then
  home_abbr="${cwd/#$HOME/~}"
  dir_display="$home_abbr"
else
  dir_display="$(pwd | sed "s|$HOME|~|")"
fi

# --- Git branch ---
git_branch=""
if git_branch_raw=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  git_branch=" $git_branch_raw"
fi

# --- Model ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- Context remaining ---
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
ctx_str=""
if [ -n "$remaining" ]; then
  remaining_int=$(printf '%.0f' "$remaining")
  if [ "$remaining_int" -le 20 ]; then
    ctx_color='\033[0;31m'   # red
  elif [ "$remaining_int" -le 50 ]; then
    ctx_color='\033[0;33m'   # yellow
  else
    ctx_color='\033[0;32m'   # green
  fi
  ctx_str=" $(printf "${ctx_color}ctx:${remaining_int}%%\033[0m")"
fi

# --- Caveman badge ---
caveman=""
caveman_script="$HOME/.claude/plugins/cache/caveman/caveman/ec83e5bace4c/src/hooks/caveman-statusline.sh"
if [ -f "$caveman_script" ]; then
  caveman_out=$(bash "$caveman_script" 2>/dev/null)
  [ -n "$caveman_out" ] && caveman=" $caveman_out"
fi

# --- Assemble ---
printf '\033[0;34m%s\033[0m' "$dir_display"
[ -n "$git_branch" ] && printf ' \033[0;35m%s\033[0m' "$git_branch"
[ -n "$model" ] && printf ' \033[0;36m%s\033[0m' "$model"
printf '%s' "$ctx_str"
printf '%s' "$caveman"

exit 0
