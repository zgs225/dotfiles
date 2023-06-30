autoload -Uz compinit
compinit

if command -v kubectl &> /dev/null; then
  source <(kubectl completion zsh)
fi
