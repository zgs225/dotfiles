# rbenv install: https://github.com/rbenv/rbenv-installer#rbenv-installer

export RBENV_ROOT="${HOME}/.rbenv"

[[ -s "${RBENV_ROOT}/bin/rbenv" ]] && eval "$(${RBENV_ROOT}/bin/rbenv init - --no-rehash zsh)"
