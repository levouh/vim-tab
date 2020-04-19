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

    function! tab#remove_buffers()
        if !exists('g:_tab_set')
            return
        endif

        let l:known_tabs = {}
        for l:tabnr in range(1, tabpagenr('$'))
            let l:known_tabs[l:tabnr] = 1
        endfor

        for l:tabnr in keys(g:_tab_set)
            let l:tabid = s:get_tabid(l:tabnr)

            if !has_key(l:known_tabs, l:tabid)
                let l:bufnames = keys(g:_tab_set[l:tabid])

                for l:buf in l:bufnames
                    try
                        exe 'bwipeout' . bufnr(l:buf)
                    catch | | endtry
                endfor

                unlet g:_tab_set[l:tabid]
            endif
        endfor
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

" }}}
