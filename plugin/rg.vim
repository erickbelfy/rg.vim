" Location:     plugin/rg.vim
" Maintainer:   Erick Belfort <http://erickbelfort.com/>
" Version:      0.1
" GetLatestVimScripts: 4504 1 :AutoInstall: rg.vim
"
"
command! -bang -nargs=* -complete=file Rg call rg#Rg('grep<bang>',<q-args>)
command! -bang -nargs=* -complete=file RgBuffer call rg#RgBuffer('grep<bang>',<q-args>)
