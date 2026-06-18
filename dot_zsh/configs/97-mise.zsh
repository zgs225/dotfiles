# mise: dev tool version manager (rust, go, node, python, lua; luarocks bundled)
if command -v mise &>/dev/null; then
  export MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise"
  eval "$(mise activate zsh)"
fi
