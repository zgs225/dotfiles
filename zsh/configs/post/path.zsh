# ensure dotfiles bin directory is loaded first
PATH="$HOME/.bin:/usr/local/sbin:$HOME/.local/bin:$PATH"

# Try loading ASDF from the regular home dir location
if [ -f "$HOME/.asdf/asdf.sh" ]; then
  . "$HOME/.asdf/asdf.sh"
elif which brew >/dev/null &&
  BREW_DIR="$(dirname `which brew`)/.." &&
  [ -f "$BREW_DIR/opt/asdf/asdf.sh" ]; then
  . "$BREW_DIR/opt/asdf/asdf.sh"
fi

# Try loading protoc
PROTOC_HOME="/opt/protoc"
if [ -d "${PROTOC_HOME}" ]; then
  PATH="${PROTOC_HOME}/bin:${PATH}"
fi

# mkdir .git/safe in the root of repositories you trust
PATH=".git/safe/../../bin:$PATH"

export -U PATH
