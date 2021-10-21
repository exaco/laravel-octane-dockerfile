php() {
  echo "Running PHP as octane user ..."
  su octane -c "php $*"
}

tinker() {
  if [ -z "$1" ]; then
    php artisan tinker
  else
    php artisan tinker --execute="\"dd($1);\""
  fi
}

# Determine size of a file or total size of a directory
fs() {
  if du -b /dev/null >/dev/null 2>&1; then
    local arg=-sbh
  else
    local arg=-sh
  fi
  if [[ -n "$@" ]]; then
    du $arg -- "$@"
  else
    du $arg .[^.]* ./*
  fi
}

# Commonly used aliases
alias ..="cd .."
alias ...="cd ../.."
alias art="php artisan"
