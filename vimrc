" Leader
let mapleader = ","

" Highlight current line
au WinLeave * set nocursorline nocursorcolumn
au WinEnter * set cursorline cursorcolumn
set cursorline cursorcolumn

set encoding=utf-8
set backspace=2   " Backspace deletes like most programs in insert mode
set nobackup
set nowritebackup
set noswapfile    " http://robots.thoughtbot.com/post/18739402579/global-gitignore#comment-458413287
set history=50
set ruler         " show the cursor position all the time
set showcmd       " display incomplete commands
set incsearch     " do incremental searching
set laststatus=2  " Always display the status line
set autowrite     " Automatically :write before running commands
set confirm       " Need confrimation while exit
set fileencodings=utf-8,gb18030,gbk,big5
set modelines=0   " Disable modelines as a security precaution
set nomodeline
set hidden
set signcolumn=number
set tabstop=4
set shiftwidth=4
set shiftround
set expandtab
set list listchars=tab:»·,trail:·,nbsp:·
set nojoinspaces
set updatetime=300

let g:is_posix = 1


" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if (&t_Co > 2 || has("gui_running")) && !exists("syntax_on")
  syntax on
endif

if filereadable(expand("~/.vimrc.bundles"))
  source ~/.vimrc.bundles
endif

if filereadable(expand("~/.vimrc.coc"))
  source ~/.vimrc.coc
endif

" Load matchit.vim, but only if the user hasn't installed a newer version.
if !exists('g:loaded_matchit') && findfile('plugin/matchit.vim', &rtp) ==# ''
  runtime! macros/matchit.vim
endif

filetype plugin indent on

augroup vimrcEx
  autocmd!

  " When editing a file, always jump to the last known cursor position.
  " Don't do it for commit messages, when the position is invalid, or when
  " inside an event handler (happens when dropping a file on gvim).
  autocmd BufReadPost *
    \ if &ft != 'gitcommit' && line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif

  " Set syntax highlighting for specific file types
  autocmd BufRead,BufNewFile *.md set filetype=markdown
  autocmd BufRead,BufNewFile .{jscs,jshint,eslint}rc set filetype=json
  autocmd BufRead,BufNewFile
    \ aliases.local,
    \zshenv.local,zlogin.local,zlogout.local,zshrc.local,zprofile.local,
    \*/zsh/configs/*
    \ set filetype=sh
  autocmd BufRead,BufNewFile gitconfig.local set filetype=gitconfig
  autocmd BufRead,BufNewFile tmux.conf.local set filetype=tmux
  autocmd BufRead,BufNewFile vimrc.local set filetype=vim
  autocmd BufRead,BufNewFile *.sshconfig set filetype=sshconfig
  autocmd BufRead,BufNewFile Makefile.* setlocal filetype=make
  autocmd FileType make setlocal noexpandtab shiftwidth=4 softtabstop=4
  autocmd BufRead,BufNewFile Dockerfile.* set filetype=dockerfile

  " Enable spellchecking for Markdown
  autocmd FileType markdown setlocal spell
  " Automatically wrap at 80 characters for Markdown
  autocmd BufRead,BufNewFile *.md setlocal textwidth=80

  au FileType python setlocal textwidth=0

  function! s:goyo_enter()
      if executable('tmux') && strlen($TMUX)
          silent !tmux set status off
          silent !tmux list-panes -F '\#F' | grep -q Z || tmux resize-pane -Z
      endif
      set noshowmode
      set noshowcmd
      set scrolloff=999
      Limelight
      " quit even goyo is active
      let b:quitting = 0
      let b:quitting_bang = 0
      autocmd QuitPre <buffer> let b:quitting = 1
      cabbrev <buffer> q! let b:quitting_bang = 1 <bar> q!
  endfunction

  function! s:goyo_leave()
      if executable('tmux') && strlen($TMUX)
          silent !tmux set status on
          silent !tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z
      endif
      set showmode
      set showcmd
      set scrolloff=5
      Limelight!
      " Quit Vim if this is the only remaining buffer
      if b:quitting && len(filter(range(1, bufnr('$')), 'buflisted(v:val)')) == 1
          if b:quitting_bang
              qa!
          else
              qa
          endif
      endif
  endfunction

  autocmd User GoyoEnter nested call <SID>goyo_enter()
  autocmd User GoyoLeave nested call <SID>goyo_leave()
augroup END

" Use The Silver Searcher https://github.com/ggreer/the_silver_searcher
if executable('ag')
  " Use Ag over Grep
  set grepprg=ag\ --nogroup\ --nocolor

  " Use ag in fzf for listing files. Lightning fast and respects .gitignore
  let $FZF_DEFAULT_COMMAND = 'ag --literal --files-with-matches --nocolor --hidden -g ""'

  if !exists(":Ag")
    command -nargs=+ -complete=file -bar Ag silent! grep! <args>|cwindow|redraw!
    nnoremap \ :Ag<SPACE>
  endif
endif

" Color scheme
set background=dark
colorscheme gruvbox-material
hi MsgArea ctermbg=Black
let g:airline_theme='gruvbox_material'

" Make it obvious where 80 characters is
set textwidth=80
set colorcolumn=+1

" Numbers
set number
set numberwidth=5

" Switch between the last two files
nnoremap <Leader><Leader> <C-^>

" Reload vimrc
nmap <Leader>R :so $MYVIMRC<CR><BAR>:echo "Reloaded"<CR>

" Get off my lawn
nnoremap <Left> :echoe "Use h"<CR>
nnoremap <Right> :echoe "Use l"<CR>
nnoremap <Up> :echoe "Use k"<CR>
nnoremap <Down> :echoe "Use j"<CR>

" vim-test mappings
nnoremap <silent> <Leader>t :TestFile<CR>
nnoremap <silent> <Leader>s :TestNearest<CR>
nnoremap <silent> <Leader>l :TestLast<CR>
nnoremap <silent> <Leader>a :TestSuite<CR>
nnoremap <silent> <Leader>gt :TestVisit<CR>

" Run commands that require an interactive shell
nnoremap <Leader>r :RunInInteractiveShell<Space>

" Treat <li> and <p> tags like the block tags they are
let g:html_indent_tags = 'li\|p'

" Set tags for vim-fugitive
set tags^=.git/tags

" Open new split panes to right and bottom, which feels more natural
set splitbelow
set splitright

" Quicker window movement
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l

set statusline+=%{fugitive#statusline()} "  Git Hotness

" Nerd Tree
let NERDChristmasTree=0
let NERDTreeWinSize=35
let NERDTreeChDirMode=2
let NERDTreeIgnore=['\~$', '\.pyc$', '\.swp$']
let NERDTreeShowBookmarks=1
let NERDTreeWinPos="left"
autocmd vimenter * if !argc() | NERDTree | endif " Automatically open a NERDTree if no files where specified
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif " Close vim if the only window left open is a NERDTree
nmap <F5> :NERDTreeToggle<CR>
nmap <leader>n :NERDTreeFind<CR>

" Search results high light
set hlsearch

" nohlsearch shortcut
nmap -hl :nohlsearch<cr>
nmap +hl :set hlsearch<cr>

" Javascript syntax hightlight
syntax enable

" ctrap
set wildignore+=*/tmp/*,*.so,*.swp,*.zip  " MacOSX/Linux
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'

nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
" Allow saving of files as sudo when I forgot to start vim using sudo.
cmap w!! w !sudo tee > /dev/null %

" Snippets author
let g:snips_author = 'Yuez'

" Move between linting errors
nnoremap ]r :ALENextWrap<CR>
nnoremap [r :ALEPreviousWrap<CR>

" Map Ctrl + p to open fuzzy find (FZF)
nnoremap <c-p> :Files<cr>

" Set spellfile to location that is guaranteed to exist, can be symlinked to
" Dropbox or kept in Git and managed outside of thoughtbot/dotfiles using rcm.
set spellfile=$HOME/.vim-spell-en.utf-8.add

" Autocomplete with dictionary words when spell check is on
set complete+=kspell

" Local config
if filereadable($HOME . "/.vimrc.local")
  source ~/.vimrc.local
endif

" Tagbar
let g:tagbar_width = 35
let g:tagbar_autofocus = 1

nmap <F6> :TagbarToggle<CR>

" Move current line quickly
nnoremap [e  :<c-u>execute 'move -1-'. v:count1<cr>
nnoremap ]e  :<c-u>execute 'move +'. v:count1<cr>

" Edit macros
nnoremap <leader>m  :<c-u><c-r>='let @'. v:register .' = '. string(getreg(v:register))<cr><c-f><left>

" insert mode
imap <C-b> <Left>
imap <C-f> <Right>
imap <C-e> <Esc>A
imap <C-a> <Esc>I

" Tab navigation
nmap tp :tabp<cr>
nmap tn :tabn<cr>
nmap tm :tabmove 

" Jump to definition in new tab
nmap <silent><Leader><c-]> <c-w><c-]><c-w>T

" ack
let g:ackprg = 'ag --vimgrep --smart-case'
cnoreabbrev ag Ack
cnoreabbrev aG Ack
cnoreabbrev Ag Ack
cnoreabbrev AG Ack

" vim-go
let g:go_code_completion_enabled = 0
" Disable gopls at vim-go, will start a gopls process at coc-vim for golang
let g:go_gopls_enabled = 0
let g:go_def_mapping_enabled = 0
let g:go_highlight_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_extra_types = 1
let g:go_highlight_operators = 1
let g:go_highlight_function_parameters = 1
let g:go_highlight_function_calls = 1
let g:go_highlight_format_strings = 1
let g:go_highlight_variable_declarations = 1
let g:go_highlight_variable_assignments = 1
let g:go_highlight_debug = 0

let g:go_debug_windows = {
          \ 'vars':       'botright 30vnew',
          \ 'stack':      'topleft 30vnew',
          \ 'goroutines': 'leftabove 20new',
          \ 'out':        'botright 5new',
\}

let g:go_debug_breakpoint_sign_text = '✑'

let g:go_debug_mappings = {
  \ '(go-debug-continue)': {'key': 'c', 'arguments': '<nowait>'},
  \ '(go-debug-print)': {'key': 'p'},
  \ '(go-debug-breakpoint)': {'key': '<F9>'},
  \ '(go-debug-stop)': {'key': '<F7>', 'arguments': '<nowait>'},
  \ '(go-debug-next)': {'key': 'n', 'arguments': '<nowait>'},
  \ '(go-debug-step)': {'key': 's'},
  \ '(go-debug-stepout)': {'key': 'o'},
\}

" copilot
imap <silent><script><expr> <C-j> copilot#Accept("\<CR>")
let g:copilot_no_tab_map = v:true

" GitGutter
command! -nargs=0 GG :GitGutter
