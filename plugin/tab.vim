" Verification {{{1

    if exists('g:_loaded_tab') || v:version < 802 || &cp
        finish
    endif

    let g:_loaded_tab = 1

" Variables {{{1

    " Keep a dictionary of buffers opened/closed in different tabs
    let g:_tab_set = {}

    " Tab ID tracking
    let g:_tab_idx = 0

" Autocommands {{{1

    augroup tab | au!
        au BufAdd,VimEnter * call tab#add_buffer(tabpagenr())

        au BufWipeout * call tab#remove_buffer(tabpagenr())
        au TabClosed * call tab#remove_buffers()

        " Needs to be an autocommand so that the tab page is correct
        au TabEnter * call tab#set_tab_name(v:true)
        "                                      │
        "                                      └ prompt user to name tab
    augroup END

" Commands {{{1

    " Clear all hidden buffers for the current tab
    command -nargs=0 TabClear call tab#clear_hidden()

    " Open the buffer list using fzf
    command! -bang TabBuffers call tab#wrap_fzf(<bang>0)
