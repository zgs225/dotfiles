# load our own completion functions
fpath=(~/.zsh/completion /usr/local/share/zsh/site-functions $fpath)

# completion; use cache if updated within 24h
autoload -Uz compinit
if [[ -n $HOME/.zcompdump(#qN.mh+24) ]]; then
  compinit -d $HOME/.zcompdump;
else
  compinit -C;
fi;

# disable zsh bundled function mtools command mcd
# which causes a conflict.
compdef -d mcd

# Tool-specific completions
if command -v kubectl &> /dev/null; then
  source <(kubectl completion zsh)
fi

if command -v argocd &> /dev/null; then
  source <(argocd completion zsh)
  compdef _argocd argocd
fi

if command -v qshell &> /dev/null; then
  source <(qshell completion zsh)
fi
