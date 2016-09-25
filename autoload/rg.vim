" Location of the rg utility
if !exists("g:rg_prg")
  if split(system("rg --column"), "[ \n\r\t]")[2] =~ '\d\+.\(\(2[5-9]\)\|\([3-9][0-9]\)\)\(.\d\+\)\?'
    let g:rg_prg="rg --column"
  else
    let g:rg_prg="rg --column --no-heading"
  endif
endif

if !exists("g:rg_apply_qmappings")
  let g:rg_apply_qmappings=1
endif

if !exists("g:rg_apply_lmappings")
  let g:rg_apply_lmappings=1
endif

if !exists("g:rg_qhandler")
  let g:rg_qhandler="botright copen"
endif

if !exists("g:rg_lhandler")
  let g:rg_lhandler="botright lopen"
endif

if !exists("g:rg_mapping_message")
  let g:rg_mapping_message=1
endif

if !exists("g:rg_working_path_mode")
    let g:rg_working_path_mode = 'c'
endif

function! rg#RgBuffer(cmd, args)
  let l:bufs = filter(range(1, bufnr('$')), 'buflisted(v:val)')
  let l:files = []
  for buf in l:bufs
    let l:file = fnamemodify(bufname(buf), ':p')
    if !isdirectory(l:file)
      call add(l:files, l:file)
    endif
  endfor
  call rg#Rg(a:cmd, a:args . ' ' . join(l:files, ' '))
endfunction

function! rg#Rg(cmd, args)
  let l:rg_exe = get(split(g:rg_prg, " "), 0)

  " Ensure that `rg` is installed
  if !executable(l:rg_exe)
    echoe "Rg command '" . l:rg_exe . "' was not found. Is the ripgrep installed and on your machine?"
    return
  endif

  " If no pattern is provided, search for the word under the cursor
  if empty(a:args)
    let l:grepargs = expand("<cword>")
  else
    let l:grepargs = a:args . join(a:000, ' ')
  end

  if empty(l:grepargs)
    echo "Usage: ':Rg {pattern}' (or just :Rg to search for the word under the cursor). See ':help :Rg' for more information."
    return
  endif

  " Format, used to manage column jump
  if a:cmd =~# '-g$'
    let s:rg_format_backup=g:rg_format
    let g:rg_format="%f"
  elseif exists("s:rg_format_backup")
    let g:rg_format=s:rg_format_backup
  elseif !exists("g:rg_format")
    let g:rg_format="%f:%m"
  endif

  let l:grepprg_bak=&grepprg
  let l:grepformat_bak=&grepformat
  let l:t_ti_bak=&t_ti
  let l:t_te_bak=&t_te
  try
    let &grepprg=g:rg_prg
    let &grepformat=g:rg_format
    set t_ti=
    set t_te=
    if g:rg_working_path_mode ==? 'r' " Try to find the projectroot for current buffer
      let l:cwd_back = getcwd()
      let l:cwd = s:guessProjectRoot()
      try
        exe "lcd ".l:cwd
      catch
        echom 'Failed to change directory to:'.l:cwd
      finally
        silent! execute a:cmd . " " . escape(l:grepargs, '|')
        exe "lcd ".l:cwd_back
      endtry
    else " Someone chose an undefined value or 'c' so we revert to the default
      silent! execute a:cmd . " " . escape(l:grepargs, '|')
    endif
  finally
    let &grepprg=l:grepprg_bak
    let &grepformat=l:grepformat_bak
    let &t_ti=l:t_ti_bak
    let &t_te=l:t_te_bak
  endtry

  if a:cmd =~# '^l'
    let l:match_count = len(getloclist(winnr()))
  else
    let l:match_count = len(getqflist())
  endif

  if a:cmd =~# '^l' && l:match_count
    exe g:rg_lhandler
    let l:apply_mappings = g:rg_apply_lmappings
    let l:matches_window_prefix = 'l' " we're using the location list
  elseif l:match_count
    exe g:rg_qhandler
    let l:apply_mappings = g:rg_apply_qmappings
    let l:matches_window_prefix = 'c' " we're using the quickfix window
  endif

  echoe  l:match_count
  " If highlighting is on, highlight the search keyword.
  if exists('g:rg_highlight')
    let @/ = matchstr(a:args, "\\v(-)\@<!(\<)\@<=\\w+|['\"]\\zs.{-}\\ze['\"]")
    call feedkeys(":let &hlsearch=1 \| echo \<CR>", 'n')
  end

  redraw!

  if l:match_count
    if l:apply_mappings
      nnoremap <silent> <buffer> h  <C-W><CR><C-w>K
      nnoremap <silent> <buffer> H  <C-W><CR><C-w>K<C-w>b
      nnoremap <silent> <buffer> o  <CR>
      nnoremap <silent> <buffer> t  <C-w><CR><C-w>T
      nnoremap <silent> <buffer> T  <C-w><CR><C-w>TgT<C-W><C-W>
      nnoremap <silent> <buffer> v  <C-w><CR><C-w>H<C-W>b<C-W>J<C-W>t

      exe 'nnoremap <silent> <buffer> e <CR><C-w><C-w>:' . l:matches_window_prefix .'close<CR>'
      exe 'nnoremap <silent> <buffer> go <CR>:' . l:matches_window_prefix . 'open<CR>'
      exe 'nnoremap <silent> <buffer> q  :' . l:matches_window_prefix . 'close<CR>'

      exe 'nnoremap <silent> <buffer> gv :let b:height=winheight(0)<CR><C-w><CR><C-w>H:' . l:matches_window_prefix . 'open<CR><C-w>J:exe printf(":normal %d\<lt>c-w>_", b:height)<CR>'
      " Interpretation:
      " :let b:height=winheight(0)<CR>                      Get the height of the quickfix/location list window
      " <CR><C-w>                                           Open the current item in a new split
      " <C-w>H                                              Slam the newly opened window against the left edge
      " :copen<CR> -or- :lopen<CR>                          Open either the quickfix window or the location list (whichever we were using)
      " <C-w>J                                              Slam the quickfix/location list window against the bottom edge
      " :exe printf(":normal %d\<lt>c-w>_", b:height)<CR>   Restore the quickfix/location list window's height from before we opened the match

      if g:rg_mapping_message && l:apply_mappings
        echom "rg.vim keys: q=quit <cr>/e/t/h/v=enter/edit/tab/split/vsplit go/T/H/gv=preview versions of same"
      endif
    endif
  else " Close the split window automatically:
    cclose
    lclose
    echohl WarningMsg
    echom 'No matches for "'.a:args.'"'
    echohl None
  endif
endfunction

function! s:guessProjectRoot()
  let l:splitsearchdir = split(getcwd(), "/")

  while len(l:splitsearchdir) > 2
    let l:searchdir = '/'.join(l:splitsearchdir, '/').'/'
    for l:marker in ['.rootdir', '.git', '.hg', '.svn', 'bzr', '_darcs', 'build.xml']
      " found it! Return the dir
      if filereadable(l:searchdir.l:marker) || isdirectory(l:searchdir.l:marker)
        return l:searchdir
      endif
    endfor
    let l:splitsearchdir = l:splitsearchdir[0:-2] " Splice the list to get rid of the tail directory
  endwhile

  " Nothing found, fallback to current working dir
  return getcwd()
endfunction
