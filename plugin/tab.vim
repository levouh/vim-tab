" --- Verification {{{

    if exists('g:_loaded_tab') || v:version < 802 || &cp
        finish
    endif

    let g:_loaded_tab = 1

" }}}

" --- Veriables {{{

    " Keep a dictionary of buffers opened/closed in different tabs
    let g:_tab_set = {}

    let g:_test = []
" }}}

" --- Autocommands {{{

    augroup tab
        au!

        au BufAdd,VimEnter * call tab#add_buffer(tabpagenr())
        au BufDelete * call tab#remove_buffer(tabpagenr())
    augroup END

" }}}

" --- Commands {{{

    command -bang -nargs=0 TLS call tab#ls(<bang>0)

" }}}
