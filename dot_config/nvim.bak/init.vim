let g:polyglot_disabled = ['groovy', 'Jenkinsfile', 'jenkinsfile']
call plug#begin('~/.vim/plugged')
Plug 'direnv/direnv.vim'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-fugitive'
Plug 'mbbill/undotree'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'jremmen/vim-ripgrep'
Plug 'vim-scripts/auto-pairs-gentle'
Plug 'airblade/vim-gitgutter'
Plug 'altercation/vim-colors-solarized'
Plug 'vim-airline/vim-airline'
Plug 'editorconfig/editorconfig-vim'
Plug 'nelstrom/vim-visual-star-search'
Plug 'stephpy/vim-yaml'
Plug 'whatyouhide/vim-gotham'
Plug 'endel/vim-github-colorscheme'
Plug 'sheerun/vim-polyglot'
Plug 'Yggdroot/indentLine'
Plug 'justinmk/vim-sneak'
Plug 'junegunn/seoul256.vim'
Plug 'liuchengxu/vista.vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'vimwiki/vimwiki'
Plug 'LnL7/vim-nix'

" trying wezterm
" Plug 'madhukar93/vim-tmux-navigator'
" Plug 'tmux-plugins/vim-tmux'

Plug 'wellle/tmux-complete.vim'
Plug 'preservim/nerdcommenter'
Plug 'lambdalisue/suda.vim'
Plug 'Shougo/neco-vim'
Plug 'jpalardy/vim-slime'
Plug 'martinda/Jenkinsfile-vim-syntax'
Plug 'luochen1990/rainbow'
Plug 'preservim/vimux'

Plug 'hashivim/vim-terraform'
Plug 'andrewstuart/vim-kubernetes'
Plug 'tpope/vim-rails'

Plug 'neoclide/coc-neco'
Plug 'ryanoasis/vim-devicons'
Plug 'jparise/vim-graphql'
Plug 'mfukar/robotframework-vim'

Plug 'pangloss/vim-javascript'
Plug 'leafgarland/typescript-vim'
Plug 'peitalin/vim-jsx-typescript'
Plug 'styled-components/vim-styled-components', { 'branch': 'main' }
Plug 'jparise/vim-graphql'

Plug 'glacambre/firenvim', { 'do': { _ -> firenvim#install(0, '') } }
Plug 'github/copilot.vim'
Plug 'psliwka/vim-smoothie'

Plug 'vim-test/vim-test'
Plug 'f-person/auto-dark-mode.nvim'

Plug 'lifepillar/pgsql.vim'
Plug 'tpope/vim-dadbod'
Plug 'puremourning/vimspector'
Plug 'pearofducks/ansible-vim'
Plug 'petobens/poet-v'

Plug 'rust-lang/rust.vim'

Plug 'mrjones2014/smart-splits.nvim'

"wezterm stuff
Plug 'willothy/wezterm.nvim'
Plug 'ojroques/vim-oscyank', {'branch': 'main'}

call plug#end()

" 'coc-yank' - interfereing with osc-yank??
let g:coc_global_extensions = ['coc-browser','coc-diagnostic','coc-docker','coc-eslint','coc-explorer','coc-json','coc-prettier','coc-pyright','coc-sh','coc-snippets','coc-solargraph','coc-tsserver','coc-vimlsp','coc-yaml','coc-go', 'coc-phpls', 'coc-db', '@yaegassy/coc-ansible', 'coc-fish', 'coc-rust-analyzer', 'coc-lua']

set encoding=UTF-8
set foldmethod=marker
let mapleader = " "
let g:seoul256_background = 233
colorscheme seoul256
"set guifont=Fira\ Code:h12
let g:airline_powerline_fonts = 1

" autopairs config
let g:AutoPairsShortcutBackInsert = '<M-b>'

set autowrite

" from http://howivim.com/2016/fatih-arslan/
" Search mappings: These will make it so that going to the next one in a
" search will center on the line it's found in.
nnoremap n nzzzv
nnoremap N Nzzzv

" Visual Mode */# from Scrooloose
function! s:VSetSearch()
  let temp = @@
  norm! gvy
  let @/ = '\V' . substitute(escape(@@, '\'), '\n', '\\n', 'g')
  let @@ = temp
endfunction
vnoremap * :<c-u>call <sid>vsetsearch()<cr>//<cr><c-o>
vnoremap # :<c-u>call <sid>vsetsearch()<cr>??<cr><c-o>

" trim whitespace on save
au BufWritePre * :%s/\s\+$//e

" http://stackoverflow.com/a/23696166/2140732
" don't jump while searching with *
nnoremap * *``
" keep the cursor position when switching buffers
augroup CursorPosition
  autocmd!
  autocmd BufLeave * let b:winview = winsaveview()
  autocmd BufEnter * if(exists('b:winview')) | call winrestview(b:winview) | endif
augroup END

map f <Plug>Sneak_f
map F <Plug>Sneak_F
map t <Plug>Sneak_t
map T <Plug>Sneak_T
map <C-p> :Files <CR>

nnoremap <esc> :noh<return> :lcl<return><esc>

" vista.vim
"function! NearestMethodOrFunction() abort
"  return get(b:, 'vista_nearest_method_or_function', '')
"endfunction

" set statusline+=%{NearestMethodOrFunction()}

" By default vista.vim never run if you don't call it explicitly.
"
" If you want to show the nearest function in your statusline automatically,
" you can add the following line to your vimrc
"autocmd VimEnter * call vista#RunForNearestMethodOrFunction()
let g:vista_default_executive = 'coc'
nmap <leader>v :Vista!!<cr>

" https://github.com/mbbill/undotree#usage
nmap <leader>u :UndotreeToggle<cr>
if has("persistent_undo")
   let target_path = expand('~/.undodir')

    " create the directory and any parent directories
    " if the location does not exist.
    if !isdirectory(target_path)
        call mkdir(target_path, "p", 0700)
    endif

    let &undodir=target_path
    set undofile
endif

set mouse=a
set wildignore+=*\\tmp\\*,*.swp,*.swo,*.zip,.git,.cabal-sandbox,.pyc
set wildmode=longest,list,full
set wildmenu
" from neotags README
set regexpengine=1
" Use <F2> to toggle between 'paste' and 'nopaste'
set pastetoggle=<F2>

set ignorecase
set smartcase
set smarttab
set smartindent
set autoindent
set incsearch
"
" autosave after updatetime
augroup MyAutoSave
    autocmd!
    autocmd CursorHold,CursorHoldI * if &filetype != "" && &buftype != "prompt" | update | endif
augroup END

" from coc README
" TextEdit might fail if hidden is not set.
set hidden

" Give more space for displaying messages.
set cmdheight=1

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

" Don't pass messages to |ins-completion-menu|.
set shortmess+=c

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
set signcolumn=yes
set statusline^=%{coc#status()}

" https://vi.stackexchange.com/questions/31310/search-throws-e363-pattern-uses-more-memory-than-maxmempattern
set maxmempattern=5000


"Use tab for trigger completion with characters ahead and navigate.
"NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
"other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1):
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction


" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
"inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<C-y>"

" Make <CR> to accept selected completion item or notify coc.nvim to format
" <C-g>u breaks current undo, please make your own choice.
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"


" Use `[c` and `]c` to navigate diagnostics
nmap <silent> [c <Plug>(coc-diagnostic-prev)
nmap <silent> ]c <Plug>(coc-diagnostic-next)

" Remap keys for gotos
nmap <silent>gd <Plug>(coc-definition)
nmap <silent>gy <Plug>(coc-type-definition)
nmap <silent>gi <Plug>(coc-implementation)
nmap <silent>gr <Plug>(coc-references)
nmap <leader>rn <Plug>(coc-rename)
nmap <leader>do <Plug>(coc-codeaction)

" Use K to show documentation in preview window.
function! ShowDocIfNoDiagnostic(timer_id)
  if (coc#float#has_float() == 0 && CocHasProvider('hover') == 1)
    silent call CocActionAsync('doHover')
  endif
endfunction

function! s:show_hover_doc()
  call timer_start(500, 'ShowDocIfNoDiagnostic')
endfunction

nnoremap <silent> <leader>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
nnoremap <silent> <leader>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent><nowait> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document
nnoremap <silent> <leader>o  :<C-u>CocList outline<cr>
" Search workspace symbols
nnoremap <silent> <leader>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent> <leader>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <leader>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent> <leader>p  :<C-u>CocListResume<CR>
" open explorer
nnoremap <silent> <leader>x  :<C-u>CocCommand explorer<cr>
" open yank list
nnoremap <silent> <leader>y  :<C-u>CocList -A --normal yank<cr>

nmap <silent> <leader>tn  :TestNearest<CR>
nmap <silent> <leader>tf  :TestFile<CR>
nmap <silent> <leader>ta  :TestSuite<CR>
nmap <silent> <leader>tl  :TestLast<CR>
nmap <silent> <leader>T  :TestVisit<CR>

"let g:floaterm_keymap_toggle = '<C-b>'

" save files
"inoremap <C-s> <esc>:w<cr>
"nnoremap <C-s> :w<cr>
" save and exit
inoremap <C-s> <esc>:wq!<cr>
nnoremap <C-s> :wq!<cr>
" quit discarding changes
inoremap <C-q> <esc>:qa!<cr>
nnoremap <C-q> :qa!<cr>
inoremap <C-c> <esc>:q!<cr>
nnoremap <C-c> :q!<cr>

"golang
autocmd BufWritePre *.go :silent call CocAction('runCommand', 'editor.action.organizeImport')
autocmd FileType go nmap gtj :CocCommand go.tags.add json<cr>
autocmd FileType go nmap gty :CocCommand go.tags.add yaml<cr>
autocmd FileType go nmap gtx :CocCommand go.tags.clear<cr>

" vimwiki
let g:vimwiki_list = [{'path': '~/vimwiki/',
                      \ 'syntax': 'markdown', 'ext': '.md'}]

" Write all buffers before navigating from Vim to tmux pane
let g:tmux_navigator_save_on_switch = 2
let g:tmux_navigator_disable_when_zoomed = 1

"let g:suda_smart_edit = 1

let g:slime_python_ipython = 1
let g:slime_target = "tmux"
let g:slime_paste_file = "$HOME/.slime_paste"
" If you generally run vim in a split tmux window with a REPL in the other pane:
let g:slime_default_config = {"socket_name": get(split($TMUX, ","), 0), "target_pane": ":.2"}

let g:rainbow_active = 1

let g:terraform_align=1
let g:terraform_fold_sections=1
let g:terraform_fmt_on_save=1
autocmd FileType Jenkinsfile,groovy setlocal shiftwidth=2 expandtab

vnoremap <leader>64 c<c-r>=system('base64 --decode', @")<cr><esc>
" right now disables tmux status on vim - do it when it's only vim on the
" screen
" autocmd VimEnter,VimLeave * silent !tmux set status

let g:python3_host_prog = "/home/madhukar/.pyenv/versions/neovim/bin/python"
"let g:python_host_prog = "/usr/bin/python"

cmap w!! w !sudo tee > /dev/null %
nnoremap <Leader>sv :source $MYVIMRC<CR>

" https://thoughtbot.com/blog/modern-typescript-and-react-development-in-vim
autocmd BufEnter *.{js,jsx,ts,tsx} :syntax sync fromstart
autocmd BufLeave *.{js,jsx,ts,tsx} :syntax sync clear

if isdirectory('./node_modules') && isdirectory('./node_modules/prettier')
  let g:coc_global_extensions += ['coc-prettier']
endif

if isdirectory('./node_modules') && isdirectory('./node_modules/eslint')
  let g:coc_global_extensions += ['coc-eslint']
endif


let g:firenvim_config = {
      \    'localSettings': {
      \      '.*': {
      \        'selector': 'textarea',
      \        'priority': 0,
      \        'takeover': 'never',
      \        'cmdline': 'firenvim',
      \      },
      \    },
      \  }

imap <silent><script><expr> <C-f> copilot#Accept("\<CR>")
let g:copilot_no_tab_map = v:true
let g:copilot_filetypes = {
    \ '*' : v:true,
    \ }

let g:vimspector_enable_mappings = 'HUMAN'
let g:vimspector_install_gadgets = [ 'delve' ]
" for normal mode - the word under the cursor
nmap <Leader>di <Plug>VimspectorBalloonEval
" for visual mode, the visually selected text
xmap <Leader>di <Plug>VimspectorBalloonEval
nmap <Leader><F11> <Plug>VimspectorUpFrame
nmap <Leader><F12> <Plug>VimspectorDownFrame
nmap <Leader>B     <Plug>VimspectorBreakpoints
nmap <Leader>D     <Plug>VimspectorDisassemble
"nmap <Esc> :call coc#util#float_hide() <CR>

let g:NERDDefaultAlign = 'left'
let g:NERDSpaceDelims = 1
let g:loaded_perl_provider = 0


lua << EOF
local auto_dark_mode = require('auto-dark-mode')

auto_dark_mode.setup({
  update_interval = 1000,
  set_dark_mode = function()
    vim.api.nvim_set_option('background', 'dark')
    vim.cmd('colorscheme seoul256')
  end,
  set_light_mode = function()
    vim.api.nvim_set_option('background', 'light')
    vim.cmd('colorscheme github')
  end,
})
vim.keymap.set("n", "<leader>wt", require('wezterm').switch_tab.index)

EOF
