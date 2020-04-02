" --- Public functions {{{

    function! tab#add_buffer(tabnr)
        if !exists('g:_tab_set')
            let g:_tab_set = {}
        endif

        if !has_key(g:_tab_set, a:tabnr)
            let g:_tab_set[a:tabnr] = {}
        endif

        let l:bufname = expand('<afile>')

        if !empty(l:bufname)
            let g:_tab_set[a:tabnr][l:bufname] = bufnr(l:bufname)
        endif
    endfunction

    function! tab#remove_buffer(tabnr)
        let l:bufname = expand('<afile>')

        if !exists('g:_tab_set')
            let g:_tab_set = {}
        endif

        if !has_key(g:_tab_set, a:tabnr)
            let g:_tab_set[a:tabnr] = {}
        endif

        if has_key(g:_tab_set[a:tabnr], l:bufname)
            unlet g:_tab_set[a:tabnr][l:bufname]
        endif
    endfunction

    function! tab#ls(bang)
        let l:tabnr = tabpagenr()

        if a:bang
            let l:buf_dict = {}

            " List all buffers for all tabs
            for [tab, buffers] in items(g:_tab_set)
                let l:bufnames = keys(buffers)

                " Use a dictionary to ensure uniqueness
                for l:buf in l:bufnames
                    let l:buf_dict[l:buf] = 1
                endfor
            endfor

            return keys(l:buf_dict)
        else
            " Use a dictionary to form a set
            let l:buf_dict = {}

            let l:bufnames = keys(g:_tab_set[l:tabnr])

            for l:buf in l:bufnames
                let l:buf_dict[l:buf] = 1
            endfor

            return keys(l:buf_dict)
        endif
    endfunction

" --- }}}
