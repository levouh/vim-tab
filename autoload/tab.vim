" --- Public functions {{{

    function! tab#add_buffer(tabnr)
        if !exists('g:_tab_set')
            let g:_tab_set = {}
        endif

        if !has_key(g:_tab_set, a:tabnr)
            let g:_tab_set[a:tabnr] = {}
        endif

        let g:_tab_set[a:tabnr][bufnr()] = 1
    endfunction

    function! tab#remove_buffer(tabnr)
        let l:bufnr = bufnr()

        if !exists('g:_tab_set')
            let g:_tab_set = {}
        endif

        if !has_key(g:_tab_set, a:tabnr)
            let g:_tab_set[a:tabnr] = {}
        endif

        if has_key(g:_tab_set[a:tabnr], l:bufnr)
            unlet g:_tab_set[a:tabnr][l:bufnr]
        endif
    endfunction

    function! tab#ls(bang)
        let l:tabnr = tabpagenr()

        if a:bang
            let l:buf_dict = {}

            " List all buffers for all tabs
            for [tab, buffers] in items(g:_tab_set)
                let l:bufnames = s:buffer_names(keys(buffers))

                " Use a dictionary to ensure uniqueness
                for l:buf in l:bufnames
                    let l:buf_dict[l:buf] = 1
                endfor
            endfor

            return keys(l:buf_dict)
        else
            " Use a dictionary to form a set
            let l:buf_dict = {}

            let l:bufnames = s:buffer_names(keys(g:_tab_set[l:tabnr]))

            for l:buf in l:bufnames
                let l:buf_dict[l:buf] = 1
            endfor

            return keys(l:buf_dict)
        endif
    endfunction

" --- }}}

" --- Private functions {{{

    " Names of buffers from buffer number
    function! s:buffer_names(bufnrs)
        return map(a:bufnrs, 'bufname(v:val)')
    endfunction

" --- }}}
