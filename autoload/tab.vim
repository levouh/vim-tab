" Public functions {{{1

    fu! tab#tabline() abort " {{{2
        let tabstr = ''

        " The last tab, so effectively the number of tabs
        let last_tab = tabpagenr('$')

        " The current focused tab
        let focused_tab = tabpagenr()

        if last_tab == 1
            " Don't prompt, just name the tab 'main'
            "
            " In the case that this is a new tab, the autocommand
            " for ":h TabEntered" is called and the tab prefix is
            " set that way
            call tab#set_tab_name(v:false, 'main')
        endif

        for tab_itr in range(1, last_tab)
            " Select the highlighting
            let focused = tab_itr == focused_tab
            let tabstr .= ' ' .. s:get_tab_name(tab_itr, focused)
        endfor

        " After the last tab fill with TabLineFill and reset tab page nr
        let tabstr .= '%#TabLineFill#%T'

        return tabstr
    endfu

    fu! tab#set_tab_name(prompt, ...) " {{{2
        let prefix = a:0 ? a:1 : gettabvar(tabpagenr(), '_tab_prefix', v:none)

        if prefix is# v:none && a:prompt
            let prefix = input('Enter tab name: ')
        endif

        if prefix isnot# v:none
            call settabvar(tabpagenr(), '_tab_prefix', prefix)
        endif
    endfu

    fu! tab#add_buffer(tabnr) " {{{2
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
    endfu

    fu! tab#remove_buffer(tabnr) " {{{2
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
    endfu

    fu! tab#remove_buffers() " {{{2
        " Called when a tab closes, but the autocommand
        " happens after the tab is closed, so we need to determine
        " which one is missing.
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
    endfu

    fu! tab#clear_hidden() " {{{2
        " Clear buffers for the currently focused tab
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
    endfu

    fu! tab#ls(bang) " {{{2
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
    endfu

" Private functions {{{1

    fu! s:get_tabid(...) " {{{2
        " Get the _tab_id from a tabnr, default to current tab
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
    endfu

    fu! s:delete_bufs(tabid, ...) abort " {{{2
        " Delete buffers for the given tab, if a second
        " argument is passed, it must be a dictionary with keys
        " being the buffer numbers that should not be deleted
        let l:bufnames = keys(g:_tab_set[a:tabid])
        let l:cleared = 0

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
                    silent exe 'bwipeout' . l:bufnr
                    let l:cleared = l:cleared + 1
                endif
            endif
        endfor

        if a:0
            echomsg 'Cleared ' . l:cleared . ' buffer(s)'
        endif
    endfu

    fu! s:get_tab_name(tabnr, focused) abort " {{{2
        let tab_name = gettabvar(a:tabnr, '_tab_prefix', v:none)
        let prefix = tab_name is# v:none ? '' : tab_name

        let tabstr = ''

        if a:focused
            " Highlighting for the selected tab
            let tabstr .= '%#TabLineSel#'
        else
            let tabstr .= '%#TabLine#'
        endif

        " Set the tab page number (for mouse clicks)
        let tabstr .= '%' .. a:tabnr .. 'T'

        " The directory of the tab, relative to the users home directory
        let dir_str = fnamemodify(getcwd(-1, a:tabnr), ':~')

        return tabstr .. prefix .. ' [' .. dir_str .. ']'
    endfu
