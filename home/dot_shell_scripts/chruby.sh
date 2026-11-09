#! /bin/sh

# Configure chruby, if it exists

if [[ -e "/opt/chruby/share/chruby/chruby.sh" ]]; then
  source "`brew --prefix`/opt/chruby/share/chruby/chruby.sh"
fi

if [[ -e "/opt/chruby/share/chruby/auto.sh" ]]; then
  source "`brew --prefix`/opt/chruby/share/chruby/auto.sh"
fi

which chruby 2>&1 >/dev/null
if [[ "x$?" = 'x0' ]]; then
  chruby `chruby | tail -n 1`
fi
