#!/bin/sh

set -e

# == Pre-install dependency checks ==

echo "==> Checking system dependencies..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

missing=0

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    printf "  ${GREEN}✓${NC} %s\n" "$1"
  else
    printf "  ${RED}✗${NC} %s ${YELLOW}(missing)${NC}\n" "$1"
    missing=1
  fi
}

echo "Required tools:"
check_cmd zsh
check_cmd git
check_cmd nvim
check_cmd tmux

echo ""
echo "Optional tools:"
check_cmd age

echo ""
echo "Secret management:"
if [ -f "$HOME/.config/chezmoi/key.txt" ]; then
  printf "  ${GREEN}✓${NC} chezmoi age key found\n"
else
  printf "  ${YELLOW}!${NC} chezmoi age key not found\n"
  printf "       Run: age-keygen -o ~/.config/chezmoi/key.txt\n"
  printf "       Then add your public key to chezmoi.toml recipients\n"
fi

echo ""
echo "OS: $(uname -s)"
echo "Arch: $(uname -m)"

if [ "$missing" -eq 1 ]; then
  echo ""
  printf "${YELLOW}Some dependencies are missing. Please install them before running 'chezmoi apply'.${NC}\n"
else
  printf "${GREEN}All required dependencies found.${NC}\n"
fi

# == Post-install tasks ==

echo ""
echo "==> Running post-install tasks..."

touch "$HOME/.psqlrc.local"

if grep -qw path_helper /etc/zshenv 2>/dev/null; then
  cat <<MSG
Warning: /etc/zshenv configuration file on your system may cause unexpected
PATH changes on subsequent invocations of the zsh shell. The solution is to
rename the file to zprofile:
  sudo mv /etc/{zshenv,zprofile}
MSG
fi

echo "Done."
