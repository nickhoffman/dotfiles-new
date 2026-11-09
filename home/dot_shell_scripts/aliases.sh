#! /bin/sh

# Commonly-used aliases.
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../../'
alias rm='/bin/rm -i'
alias cp='/bin/cp -i'

if [ "`uname`" = 'Darwin' ]; then
  alias ll='ls -lFG'
else
  alias ll='ls -lF --color=auto'
fi

alias llh='ll -h'
alias lla='ll -a'
alias cls='/usr/bin/clear && ll'
alias clsa='cls -a'
alias g='egrep --color'
alias gr='g -rnI'
alias gri='gr -i'
alias grep='egrep --color'
alias lg='ll | grep '
alias cg='cls | grep '
alias gdu="grep -v -e '^..K' -e '^...K' -e '^..M' -e '^.\..M' -e '^0'"
alias less='less -iR'
alias su='/bin/su -'
alias v='view'
alias sv='/usr/bin/sudo vim'
alias vi='vim -p'
alias mux='tmuxp load'


if [ "`uname`" = 'Darwin' ]; then
  alias p='/bin/ps aux'
  alias pl='/bin/ps aux | less'
else
  alias p='/bin/ps auxf'
  alias pl='/bin/ps auxf | less'
fi

# APT
# These only work on Linux.
if [[ "`uname`" == 'Linux' ]]; then
  alias atu='sudo aptitude -V update'
  alias atug='sudo aptitude -V safe-upgrade'
  alias ati='sudo aptitude -V install'
  alias atr='sudo aptitude remove'
  alias atp='sudo aptitude purge'
  alias ats='aptitude search'
  alias atsh='aptitude show'
  alias acs='apt-cache search'
  alias acsh='apt-cache show'
  alias acsn='apt-cache search --names-only'
  alias afs='apt-file search'
  alias afsh='apt-file show'
  alias d='dpkg'
fi

# Development
alias bi='bundle install'
alias be='bundle exec'
alias berc='be rails console'
alias as_json='python -m json.tool'
alias ss='bin/spring stop'

# Miscellaneous
alias showcpu='/bin/ps auxf | head -1; /bin/ps auxf | sort -nr -k 3'
alias showmem='/bin/ps auxf | head -1; /bin/ps auxf | sort -nr -k 4'
alias pv='pv -N "pv"'
alias shred='shred -u'
alias open-ports="sudo lsof -iTCP -sTCP:LISTEN -P"

# For backing up my data at home.
if [[ "`uname`" == 'Linux' ]]; then
  alias rsync-backup-home='sudo rsync -avzh --hard-links --inplace --numeric-ids --itemize-changes --delete-after --ignore-errors /home/ /mnt/backup-home'
  alias rsync-backup-os='sudo rsync -avzhx --hard-links --inplace --numeric-ids --itemize-changes --delete-after --ignore-errors --exclude /dev --exclude /mnt --exclude /proc --exclude /sys --exclude /tmp / /mnt/backup-os/'
fi

# Show network connections.
if [ "`uname`" = 'Darwin' ]; then
  alias nst='sudo netstat -taun'
else
  alias nst='sudo netstat -taunp'
fi

# This is for smart running of tests.
function rt {
  if grep -q "spring-commands-testunit" Gemfile; then
    bundle exec spring testunit $@
  elif grep -q "spring-commands-rspec" Gemfile; then
    bundle exec spring rspec $@
  elif [ -d 'spec' ]; then
    bundle exec rspec $1
  else
    bundle exec ruby -Itest $@
  fi
}

# Run tests that contain "focus" in their name.
function rtf {
  rt $@ -n /focus/
}

# Run tests and format the output as documentation.
function rtd {
  rt $@ -f d
}
