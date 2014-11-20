"---------------------------------------------------------------------------
" unite.vim
"

" Default configuration.
let default_context = {
			\ 'vertical' : 0,
			\ 'cursor_line_highlight' : 'TabLineSel',
			\ 'complete' : 1,
			\ }

let g:unite_enable_short_source_names = 1
" let g:unite_abbr_highlight = 'TabLine'

if IsWindows()
else
	" Like Textmate icons.
	let g:unite_marked_icon = '✗'
	let default_context.prompt = '» '
endif

call unite#custom#profile('default', 'context', default_context)

let g:unite_kind_file_vertical_preview = 1

let g:unite_split_rule = "botright"
let g:unite_force_overwrite_statusline = 0
let g:unite_source_history_yank_enable = 1

" For unite-alias.
let g:unite_source_alias_aliases = {}
let g:unite_source_alias_aliases.line_migemo = 'line'
let g:unite_source_alias_aliases.calc = 'kawaii-calc'
let g:unite_source_alias_aliases.l = 'launcher'
let g:unite_source_alias_aliases.kill = 'process'
let g:unite_source_alias_aliases.message = {
			\ 'source' : 'output',
			\ 'args'   : 'message',
			\ }
let g:unite_source_alias_aliases.mes = {
			\ 'source' : 'output',
			\ 'args'   : 'message',
			\ }
let g:unite_source_alias_aliases.scriptnames = {
			\ 'source' : 'output',
			\ 'args'   : 'scriptnames',
			\ }

autocmd MyAutoCmd FileType unite call s:unite_my_settings()

let g:unite_ignore_source_files = []

call unite#custom#profile('action', 'context', {
			\ 'start_insert' : 1
			\ })

" migemo.
call unite#custom#source('line_migemo', 'matchers', 'matcher_migemo')

" Custom filters."{{{
call unite#custom#source(
			\ 'buffer,file_rec,file_rec/async,file_rec/git', 'matchers',
			\ ['converter_relative_word', 'matcher_fuzzy',
			\  'matcher_project_ignore_files'])
call unite#custom#source(
			\ 'file_mru', 'matchers',
			\ ['matcher_project_files', 'matcher_fuzzy'])
" call unite#custom#source(
"       \ 'file', 'matchers',
"       \ ['matcher_fuzzy', 'matcher_hide_hidden_files'])
call unite#custom#source(
			\ 'file_rec,file_rec/async,file_rec/git,file_mru', 'converters',
			\ ['converter_file_directory'])
call unite#filters#matcher_default#use(['matcher_fuzzy'])
call unite#filters#sorter_default#use(['sorter_rank'])
"}}}

function! s:unite_my_settings() "{{{
	" Directory partial match.
	call unite#custom#alias('file', 'h', 'left')
	call unite#custom#default_action('directory', 'narrow')

	call unite#custom#default_action('versions/git/status', 'commit')

	" Overwrite settings.
	imap <silent><buffer><expr> <C-x> unite#do_action('split')
	nmap <silent><buffer><expr> <C-x> unite#do_action('split')
	imap <silent><buffer><expr> <C-v> unite#do_action('vsplit')
	nmap <silent><buffer><expr> <C-v> unite#do_action('vsplit')
	imap <silent><buffer><expr> <C-t> unite#do_action('tabopen')
	nmap <silent><buffer><expr> <C-t> unite#do_action('tabopen')
	imap <buffer>  jj        <Plug>(unite_insert_leave)
	imap <buffer>  <Tab>     <Plug>(unite_complete)
	imap <buffer> <C-w>      <Plug>(unite_delete_backward_path)
	imap <buffer> '          <Plug>(unite_quick_match_default_action)
	nmap <buffer> '          <Plug>(unite_quick_match_default_action)
	nmap <buffer> cd         <Plug>(unite_quick_match_default_action)
	nmap <buffer> <C-z>      <Plug>(unite_toggle_transpose_window)
	imap <buffer> <C-z>      <Plug>(unite_toggle_transpose_window)
	imap <buffer> <C-w>      <Plug>(unite_delete_backward_path)
	nmap <buffer> <C-j>      <Plug>(unite_toggle_auto_preview)
	nnoremap <silent><buffer> <Tab>     <C-w>w
	nnoremap <silent><buffer><expr> l
				\ unite#smart_map('l', unite#do_action('default'))
	nnoremap <silent> /  :<C-u>Unite -buffer-name=search
				\ line -start-insert -no-quit<CR>

	let unite = unite#get_current_unite()
	if unite.profile_name ==# '^search'
		nnoremap <silent><buffer><expr> r     unite#do_action('replace')
	else
		nnoremap <silent><buffer><expr> r     unite#do_action('rename')
	endif

	nnoremap <silent><buffer><expr> cd     unite#do_action('lcd')
	nnoremap <silent><buffer><expr> x     unite#do_action('start')
	nnoremap <buffer><expr> S      unite#mappings#set_current_filters(
				\ empty(unite#mappings#get_current_filters()) ? ['sorter_reverse'] : [])
endfunction"}}}

if executable('ag')
	" Use ag in unite grep source.
	let g:unite_source_grep_command = 'ag'
	let g:unite_source_grep_default_opts =
				\ '--line-numbers --nocolor --nogroup --hidden --ignore ' .
				\  '''.hg'' --ignore ''.svn'' --ignore ''.git'' --ignore ''.bzr'''
	let g:unite_source_grep_recursive_opt = ''
elseif executable('pt')
	let g:unite_source_grep_command = 'pt'
	let g:unite_source_grep_default_opts = '--nogroup --nocolor'
	let g:unite_source_grep_recursive_opt = ''
elseif executable('jvgrep')
	" For jvgrep.
	let g:unite_source_grep_command = 'jvgrep'
	let g:unite_source_grep_default_opts = '--exclude ''\.(git|svn|hg|bzr)'''
	let g:unite_source_grep_recursive_opt = '-R'
elseif executable('ack-grep')
	" For ack.
	let g:unite_source_grep_command = 'ack-grep'
	let g:unite_source_grep_default_opts = '--no-heading --no-color -a'
	let g:unite_source_grep_recursive_opt = ''
endif

let g:unite_build_error_icon    = '~/.vim/signs/err.'
			\ . (IsWindows() ? 'bmp' : 'png')
let g:unite_build_warning_icon  = '~/.vim/signs/warn.'
			\ . (IsWindows() ? 'bmp' : 'png')
let g:unite_source_rec_max_cache_files = -1
call unite#custom_source('file_rec,file_rec/async,file_mru,file,buffer,grep',
			\ 'ignore_pattern', join([
			\ '\.git/',
			\ ], '\|'))

" Source Menu
call g:Source_rc('plugins/unite.menu.vim')

