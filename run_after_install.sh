#!/bin/sh

set -e

echo "==> Running post-install tasks..."

touch "$HOME/.psqlrc.local"

if [ -f "$HOME/.git_template/HEAD" ] && \
  [ "$(cat "$HOME/.git_template/HEAD")" = "ref: refs/heads/main" ]; then
  echo "Removing ~/.git_template/HEAD in favor of defaultBranch"
  rm -f ~/.git_template/HEAD
fi

if grep -qw path_helper /etc/zshenv 2>/dev/null; then
  cat <<MSG
Warning: /etc/zshenv configuration file on your system may cause unexpected
PATH changes on subsequent invocations of the zsh shell. The solution is to
rename the file to zprofile:
  sudo mv /etc/{zshenv,zprofile}
MSG
fi

echo "Done."
