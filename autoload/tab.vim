" --- Public functions {{{

    function! tab#add_buffer(tabnr)
        if !exists('g:_tab_set')
            let g:_tab_set = {}
        endif

        let l:tabid = s:get_tabid(a:tabnr)

        if !has_key(g:_tab_set, l:tabid)
            let g:_tab_set[l:tabid] = {}
        endif

        let l:bufname = expand('<afile>')

        if !empty(l:bufname) && buflisted(l:bufname) && !isdirectory(l:bufname)
            let g:_tab_set[l:tabid][l:bufname] = bufnr(l:bufname)
        endif
    endfunction

    function! tab#remove_buffer(tabnr)
        let l:bufname = expand('<afile>')

        if !exists('g:_tab_set')
            let g:_tab_set = {}
        endif

        let l:tabid = s:get_tabid(a:tabnr)

        if !has_key(g:_tab_set, l:tabid)
            let g:_tab_set[l:tabid] = {}
        endif

        if has_key(g:_tab_set[l:tabid], l:bufname)
            unlet g:_tab_set[l:tabid][l:bufname]
        endif
    endfunction

    " Called when a tab closes, but the autocommand
    " happens after the tab is closed, so we need to determine
    " which one is missing.
    function! tab#remove_buffers()
        if !exists('g:_tab_set')
            return
        endif

        let l:known_tabs = {}
        for l:tabnr in range(1, tabpagenr('$'))
            let l:tabid = s:get_tabid(l:tabnr)

            if l:tabid != -1
                let l:known_tabs[l:tabid] = 1
            endif
        endfor

        for l:tabid in keys(g:_tab_set)
            if !has_key(l:known_tabs, l:tabid)
                call s:delete_bufs(l:tabid)
                unlet g:_tab_set[l:tabid]
            endif
        endfor
    endfunction

    " Clear buffers for the currently focused tab
    function! tab#clear_hidden()
        let l:tabid = s:get_tabid()
        let l:visible = {}

        if !has_key(g:_tab_set, l:tabid)
            echomsg 'Invalid tabid: ' . l:tabid
            return
        endif

        " Don't close visible buffers
        for tabnr in range(1, tabpagenr('$'))
            for bufnr in tabpagebuflist(tabnr)
                let l:visible[bufnr] = 1
            endfor
        endfor

        call s:delete_bufs(l:tabid, l:visible)
    endfunction

    function! tab#ls(bang)
        let l:tabid = s:get_tabid(tabpagenr())

        if a:bang
            let l:buf_dict = {}

            " List all buffers for all tabs
            for [tab, buffers] in items(g:_tab_set)
                let l:bufnames = keys(buffers)

                " Use a dictionary to ensure uniqueness
                for l:buf in l:bufnames
                    if !buflisted(l:buf)
                        unlet g:_tab_set[tab][l:buf]
                        continue
                    endif

                    let l:buf_dict[l:buf] = 1
                endfor
            endfor

            return keys(l:buf_dict)
        else
            " Use a dictionary to form a set
            let l:buf_dict = {}

            let l:bufnames = keys(g:_tab_set[l:tabid])

            for l:buf in l:bufnames
                if !buflisted(l:buf)
                    unlet g:_tab_set[l:tabid][l:buf]
                    continue
                endif

                let l:buf_dict[l:buf] = 1
            endfor

            return keys(l:buf_dict)
        endif
    endfunction

" }}}

" --- Private functions {{{

    " Get the _tab_id from a tabnr, default to current tab
    function! s:get_tabid(...)
        let l:tabnr = a:0 ? a:1 : tabpagenr()

        let l:tabid = gettabvar(l:tabnr, '_tab_id', -1)
        let l:tabidx = g:_tab_idx

        if l:tabid == -1
            call settabvar(l:tabnr, '_tab_id', l:tabidx)

            let g:_tab_idx = g:_tab_idx + 1

            return l:tabidx
        else
            return l:tabid
        endif
    endfunction

    " Delete buffers for the given tab, if a second
    " argument is passed, it must be a dictionary with keys
    " being the buffer numbers that should not be deleted
    function! s:delete_bufs(tabid, ...) abort
        let l:bufnames = keys(g:_tab_set[a:tabid])

        if a:0
            let l:skip = a:1
        else
            let l:skip = {}
        endif

        for l:buf in l:bufnames
            let l:bufnr = bufnr(l:buf)

            " The buffer is listed and not modified
            if buflisted(l:bufnr) && !getbufvar(l:bufnr, '&modified')
                " If the key exists, don't delete the buffer
                if !has_key(l:skip, l:bufnr)
                    silent exe 'bdel' . l:bufnr
                endif
            endif
        endfor
    endfunction

" }}}
