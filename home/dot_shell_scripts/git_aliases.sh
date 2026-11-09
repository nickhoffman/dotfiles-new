#!/bin/sh

__define_git_completion () {
eval "
    _git_$2_shortcut () {
        COMP_LINE=\"git $2\${COMP_LINE#$1}\"
        let COMP_POINT+=$((4+${#2}-${#1}))
        COMP_WORDS=(git $2 \"\${COMP_WORDS[@]:1}\")
        let COMP_CWORD+=1

        local cur words cword prev
        _get_comp_words_by_ref -n =: cur words cword prev
        _git_$2
    }
"
}

__git_shortcut () {
    type _git_$2_shortcut &>/dev/null || __define_git_completion $1 $2
    alias $1="git $2 $3 $4 $5 $6"
    complete -o default -o nospace -F _git_$2_shortcut $1
}

alias git='git --no-pager'

type __git_shortcut >/dev/null 2>&1
if [ "x$?" = "x0" ]; then
  __git_shortcut gs     status
  __git_shortcut gsns   show --name-status --reverse
  __git_shortcut ga     add
  __git_shortcut gd     diff --ws-error-highlight=all
  __git_shortcut gdc    diff --ws-error-highlight=all --cached
  __git_shortcut gdh    diff --ws-error-highlight=all HEAD^ HEAD
  __git_shortcut gc     commit
  __git_shortcut gcm    commit -m
  __git_shortcut gca    commit --amend
  __git_shortcut gl     log --name-status
  __git_shortcut gl1    log --pretty=tformat:"'%C(yellow)%h%Creset%x09%an%x09%ad%x09%s'" --date=short --reverse
  __git_shortcut gl1mh  log --pretty=tformat:"'%C(yellow)%h%Creset%x09%an%x09%ad%x09%s'" --date=short --reverse master..HEAD
  __git_shortcut gb     branch
  __git_shortcut gba    branch -a
  __git_shortcut gco    checkout
  __git_shortcut gcob   checkout -b
  __git_shortcut gcom   checkout master
  __git_shortcut grm    rebase master
  __git_shortcut gp     push
  __git_shortcut gpomp  push origin master:production
  __git_shortcut gfa    fetch --all --prune
  __git_shortcut gfo    fetch --prune origin
  __git_shortcut gfom   fetch --prune origin master
  __git_shortcut gpom   pull origin master
  __git_shortcut gsa    stash apply
  __git_shortcut grc    rebase --continue
fi

alias gfop='gfo && git pull'

function git_files_changed_in_branch {
  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  common_ancestor="$(git merge-base ${current_branch} master)"
  gd --name-only $current_branch $common_ancestor
}

function gcmput {
  (set -x; gc -m "put this in $@")
}

function gcobt {
  gcob $1 -t origin/$1
}
