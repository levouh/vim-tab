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

        let tabid = s:get_tabid(a:tabnr)

        if !has_key(g:_tab_set, tabid)
            let g:_tab_set[tabid] = {}
        endif

        let bufname = expand('<afile>')
        let bufnr = str2nr(expand('<abuf>'))

        if empty(bufname)
            let bufname = '[No Name]'
        endif

        if buflisted(bufnr) && !isdirectory(bufname)
            let g:_tab_set[tabid][bufnr] = bufname
        endif
    endfu

    fu! tab#remove_buffer(tabnr) " {{{2
        let bufnr = expand('<abuf>')

        if !exists('g:_tab_set')
            let g:_tab_set = {}
        endif

        let tabid = s:get_tabid(a:tabnr)

        if !has_key(g:_tab_set, tabid)
            let g:_tab_set[tabid] = {}
        endif

        if has_key(g:_tab_set[tabid], bufnr)
            unlet g:_tab_set[tabid][bufnr]
        endif
    endfu

    fu! tab#remove_buffers() " {{{2
        " Called when a tab closes, but the autocommand
        " happens after the tab is closed, so we need to determine
        " which one is missing.
        if !exists('g:_tab_set')
            return
        endif

        let known_tabs = {}
        for tabnr in range(1, tabpagenr('$'))
            let tabid = s:get_tabid(tabnr)

            if tabid != -1
                let known_tabs[tabid] = 1
            endif
        endfor

        for tabid in keys(g:_tab_set)
            if !has_key(known_tabs, tabid)
                call s:delete_bufs(tabid)
                unlet g:_tab_set[tabid]
            endif
        endfor
    endfu

    fu! tab#clear_hidden() " {{{2
        " Clear buffers for the currently focused tab
        let tabid = s:get_tabid()
        let visible = {}

        if !has_key(g:_tab_set, tabid)
            echom 'Invalid tabid: ' .. tabid | return
        endif

        " Don't close visible buffers
        for tabnr in range(1, tabpagenr('$'))
            for bufnr in tabpagebuflist(tabnr)
                let visible[bufnr] = 1
            endfor
        endfor

        call s:delete_bufs(tabid, visible)
    endfu

    fu! tab#ls(bang) " {{{2
        let tabid = s:get_tabid(tabpagenr())
        let buf_dict = {}

        if a:bang
            " List all buffers for all tabs
            for [tab, buffers] in items(g:_tab_set)
                " This will be a list of buffer numbers
                let bufnrs = map(keys(buffers), 'str2nr(v:val)')

                " Use a dictionary to ensure uniqueness
                for bufnr in bufnrs
                    if buflisted(bufnr) == 0
                        unlet g:_tab_set[tab][bufnr]
                        continue
                    endif

                    let buf_dict[bufnr] = g:_tab_set[tabid][bufnr]
                endfor
            endfor
        else
            let bufnrs = map(keys(g:_tab_set[tabid]), 'str2nr(v:val)')

            for bufnr in bufnrs
                if buflisted(bufnr) == 0
                    unlet g:_tab_set[tabid][bufnr]
                    continue
                endif

                let buf_dict[bufnr] = g:_tab_set[tabid][bufnr]
            endfor
        endif

        return values(buf_dict)
    endfu

" Private functions {{{1

    fu! s:get_tabid(...) " {{{2
        " Get the _tab_id from a tabnr, default to current tab
        let tabnr = a:0 ? a:1 : tabpagenr()

        let tabid = gettabvar(tabnr, '_tab_id', -1)
        let tabidx = g:_tab_idx

        if tabid == -1
            call settabvar(tabnr, '_tab_id', tabidx)

            let g:_tab_idx = g:_tab_idx + 1

            return tabidx
        else
            return tabid
        endif
    endfu

    fu! s:delete_bufs(tabid, ...) abort " {{{2
        " Delete buffers for the given tab, if a second
        " argument is passed, it must be a dictionary with keys
        " being the buffer numbers that should not be deleted
        let bufnrs = map(keys(g:_tab_set[a:tabid]), 'str2nr(v:val)')
        let cleared = 0

        if a:0
            let skip = a:1
        else
            let skip = {}
        endif

        for bufnr in bufnrs
            " The buffer is listed and not modified
            if buflisted(bufnr) && !getbufvar(bufnr, '&modified')
                " If the key exists, don't delete the buffer
                if !has_key(skip, string(bufnr))
                    silent exe 'bwipeout' .. bufnr
                    let cleared = cleared + 1
                endif
            endif
        endfor

        if a:0
            echom 'Cleared ' .. cleared .. ' buffer(s)'
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
