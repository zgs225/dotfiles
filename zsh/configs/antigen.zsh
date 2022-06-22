if [ -e "$HOME"/.bin/antigen.zsh ]; then
    source "$HOME"/.bin/antigen.zsh

    antigen use oh-my-zsh

    antigen bundle z
    antigen bundle git
    antigen bundle command-not-found
    antigen bundle zsh-users/zsh-autosuggestions
    antigen bundle zsh-users/zsh-syntax-highlighting

    antigen theme robbyrussell

    antigen apply
fi
