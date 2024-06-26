if [ -e "$HOME"/.bin/antigen.zsh ]; then
    source "$HOME"/.bin/antigen.zsh

    antigen use oh-my-zsh

    antigen bundle z
    antigen bundle git
    antigen bundle command-not-found
    antigen bundle zsh-users/zsh-autosuggestions
    antigen bundle zsh-users/zsh-syntax-highlighting
    antigen bundle kubectl

    antigen theme romkatv/powerlevel10k

    antigen apply
fi
