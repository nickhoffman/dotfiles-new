execute pathogen#infect()

set nocompatible        " Be ViM. Don't be backwards compatible with Vi.
set nu                  " Enable line numbers.
set ignorecase          " Case-insensitive searches.
set nosmartcase         " Make searches case-sensitive if the search contains an upper-case character.
set noerrorbells        " Disable error bells.
set foldmethod=marker
set showcmd             " Show commands as they're typed.
set esckeys             " Allow cursor keys in insert mode.
set nohlsearch          " Disable search result highlighting.    
set noinsertmode        " Don't start vim in insert mode.
set magic               " Enable extended regexes.
set report=0            " Show all changes.
set ruler               " Show the cursor position.
set shortmess=I         " Don't show the intro message when starting vim.
set showmode            " Show the current mode.
set nostartofline       " Don't jump to the start of the line when moving around.
set title               " Show the filename in the window titlebar.
set wildmenu            " When tabbing through command possibilities, all commands are listed.
set wildchar=<TAB>      " Character for CLI expansion (TAB-completion).
"set wildmode=list:longest " Behave like BASH tab-completion.
set expandtab           " Expand tabs to spaces.
set tabstop=2           " Hitting the tab key results in 2 spaces.
set shiftwidth=2        " The # of spaces for each step of [auto-]indenting.
set backspace=indent,eol,start  " Make backspaces delete across auto-indents, EOLs and the beginning of lines
set matchpairs+=<:>     " Allow % to jump between angle brackets too.
set nopaste
set autoindent          " Preserve current indent on new lines
set showtabline=2       " Always show the tab line at the top of the screen.
set history=100         " The number of commands and search patterns to remember.
set scrolloff=5         " Start scrolling through the window when the cursor is X lines above/below the top/bottom of the buffer.
set sidescrolloff=5     " Same as above, but for horizontal motion.
set whichwrap=h,l       " Allow the 'l' and 'h' keys to move the cursor to the next and previous lines, respectively.
set wrap
set tabpagemax=50       " Allow 50 tabs.
set ls=2                " Always show the filename.

" Ignore whitespace in vimdiff.
if &diff
  " diff mode
  set diffopt+=iwhite
endif

" Set the leader character to the space character (" ").
let mapleader = " "

" Configure % to jump between if/elsif/end , and other things.
runtime macros/matchit.vim

" Indent/outdent to nearest tabstop
set shiftround

if version >= 600
  filetype on
  filetype plugin on
  filetype indent on
endif

" Set syntax highlighting options.
"set t_Co=256            " Let's use 256 colours.
syntax on
set background=dark
colorscheme peaksea

" Show a vertical line to indicate line wrapping.
highlight ColorColumn ctermbg=8
set colorcolumn=120

" Custom HTML indentation
let g:html_indent_inctags = "li"

if &diff
  " ViMDiff settings.
endif

" Set folding options.
vmap F zf
nmap F zo
nmap f zc
nmap j gj
nmap k gk
highlight Folded ctermfg=yellow ctermbg=none

" Map '<' to switch to the previous tab, and '>' to switch to the next tab.
" Tabpage documentation: http://vimdoc.sourceforge.net/htmldoc/tabpage.html
noremap < gT
noremap > gt

" Map '#' to comment out the current line, then go down one line.
" If the first character is a space, the space will be removed. Eg:
"   "not indented"  -->   "#not indented"
"   "  indented"    -->   "# indented"
"map # :s/^/#/<CR>j
nnoremap # :s/^ \?/#/<CR>j

" Map '`' (backtick) to remove the first character from the current line, then go down one line.
" If the second character is a space, a space will be added to the beginning
" of the line. Eg:
"   "#not indented"   -->   "not indented"
"   "# indented"      -->   "  indented"
"map ` :s/^.//<CR>j
nnoremap ` :s/^#\( \)\?/\1\1/<CR>j

" Map ';' to swap the position of the current line and the one below it.
noremap ; ddpk0

noremap - /<<<<<<CR>
noremap _ />>>>><CR>

" Convert tabs to two spaces.
noremap :tabstowhitespace :%s/\t/  /g

" Remove trailing spaces.
noremap :trail :s/\s\+$//

" Map CTRL+n to CTRL+w because the former is easier to type.
" This makes it easier to switch viewports.
" <C-j> isn't mapped to <C-w>j because <C-j> is used by tmux.
noremap <C-n> <C-w>
map <C-h> <C-w>h
map <C-k> <C-w>k
map <C-l> <C-w>l

" Map :ind to indent by 2 spaces.
map :ind :s/^/  /<CR>

" Map @q to convert double-quotes to single-quotes on the current line.
noremap @q :s/"/'/g<CR>

" Map @Q to convert single-quotes to double-quotes on the current line.
noremap @Q :s/'/"/g<CR>

map :ruby :set filetype=ruby
map :eruby :set filetype=eruby

" Map :Rf and :Norf to add and remove ", :focus => true" to RSpec examples and example groups.
"com! Rf :s/\([^\w]\) do\( \?\)/\1, :focus => true do\2/
"com! Rf :s/\([^\w]['")]\) do\( \?\)/\1, :focus => true do\2/
com! Rf :s/\(['")]\) do\( \?\)/\1, :focus => true do\2/
com! Norf :s/, :focus => true//

" Map :Rsp to remove extra whitespace after the first non-whitespace characters on a line.
com! Rsp :s/^\(\s*\S\+\)\s\+/\1 /

" Map :VSP to ":botright vsplit" to make it faster to create a vertical on the right.
com! -nargs=1 -complete=file VSP :botright vsplit <args>

" Redefine O because sometimes ViM isn't fast enough, and enters input mode
" on the line that O was called on, rather than on the line above.
"nmap O 0i<CR><esc>k0

" Open multiple tabs at once. Usage:
"   :AddTabs foo/*
com! -nargs=+ -complete=file AddTabs tabnew|exec "args" <q-args>|tab ball

" add jbuilder syntax highlighting
au BufNewFile,BufRead *.json.jbuilder set ft=ruby

" Reformat JSON. Not needed since I use Prettier now?
"map <leader>jt :%!python -m json.tool<CR>

" Configure CtrlP. {{{

" Load and configure CtrlP.
set runtimepath^=~/.vim/bundle/ctrlp.vim

" Ctrl-O opens CtrlP for the current word.
map <C-o> <C-P><C-\>w

" Persist the cache between ViM sessions.
let g:ctrlp_clear_cache_on_exit = 0

" Specify the cache directory.
let g:ctrlp_cache_dir = $HOME . '/.cache/ctrlp'

let g:ctrlp_user_command = 'ag %s -i --nocolor --nogroup --hidden
  \ --ignore .git
  \ --ignore .svn
  \ --ignore .hg
  \ --ignore .DS_Store
  \ --ignore vendor
  \ --ignore tmp
  \ --ignore *.so
  \ --ignore *.swo
  \ --ignore *.swp
  \ --ignore "**/*.pyc"
  \ -g ""'

" Disable opening files in a new buffer ("e").
" Default to opening files in a new tab ("t").
let g:ctrlp_prompt_mappings = {
    \ 'AcceptSelection("e")': [],
    \ 'AcceptSelection("t")': ['<cr>', '<2-LeftMouse>'],
    \ }

" }}}

" Configure the vim-ruby plugin. {{{
" See https://github.com/vim-ruby/vim-ruby/blob/master/doc/vim-ruby.txt

" Use do-style block indentation.
let g:ruby_indent_block_style = 'do'

" Use variable-style indenting assignment.
let g:ruby_indent_assignment_style = 'variable'
" }}}

" Configure Prettier formatting for JS, TS, CSS, etc. {{{

" Disable typescript-vim's custom indenter.
"let g:typescript_indent_disable = 1

let g:prettier#autoformat = 0
let g:prettier#config#tab_width = '2'
autocmd BufWritePre *.js,*.jsx,*.mjs,*.ts,*.tsx,*.css,*.less,*.scss,*.json,*.graphql,*.md,*.vue,*.yaml,*.html Prettier
" }}}

" Map <leader>f to copy the current file path to the clipboard.
map <Leader>f :let @+=expand('%')<CR>

" Map <leader>p to toggle paste mode.
map <leader>p :set invpaste<CR>
