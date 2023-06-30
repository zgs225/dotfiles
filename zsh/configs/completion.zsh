autoload -Uz compinit
compinit

if command -v kubectl &> /dev/null; then
  source <(kubectl completion zsh)
fi

if command -v argocd &> /dev/null; then
  source <(argocd completion zsh)
  compdef _argocd argocd
fi
