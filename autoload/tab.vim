" See "tab#set_tab_name" for more details on the use of this {{{
" script-local variable
let s:skip_au = v:false " }}}
" When the tabline is initially setup, it will name the initial tab {{{
" "main", assuming that this is startup if there is only a single tab
" that exists.
"
" However, when closing all tabs but the last tab, it will also find
" the same count and reset the name of the last tab to be "main" as
" well, which is not what we want. After the initial setup, just
" change the value of this variable to skip that behavior.
let s:setup_main = v:false " }}}
fu! tab#tabline() abort " {{{1
    let tabstr = ''

    " The last tab, so effectively the number of tabs
    let last_tab = tabpagenr('$')

    " The current focused tab
    let focused_tab = tabpagenr()

    if last_tab == 1 && s:setup_main is# v:false
        " Don't prompt, just name the tab 'main'
        "
        " In the case that this is a new tab, the autocommand
        " for ":h TabEntered" is called and the tab prefix is
        " set that way
        "
        " Don't force the rename to happen, this is the first
        " tab that is created and provides a clunky experience
        call tab#set_tab_name(v:false, 'main')

        " Don't do this again, when closing to the last tab for
        " instance
        let s:setup_main = v:true
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


fu! tab#tab_rename() abort " {{{1
    let prefix = input('Enter tab name: ')

    if empty(prefix)
        " User has cancelled action, or input nothing
        return
    endif

    call settabvar(tabpagenr(), '_tab_prefix', prefix)

    " Immediately show user updates
    "
    " See "tab#set_tab_name" for details on why we set "s:skip_au"
    let s:skip_au = v:true

    try
        redrawtabline
    finally
        " Ensure the value is restored, regardless of the success from
        " the above call
        let s:skip_au = v:false
    endtry
endfu

fu! tab#set_tab_name(prompt, ...) " {{{1
    if s:skip_au
        " This call actually causes this function to be called again
        " via the ":h TabEntered" autocommand, so before this function
        " even finishes, the functionality has to be put in another
        " function.
        "
        " From this we will grab the name of the tab, and effectively
        " reset it, so when this value is set to "v:true" just skip
        " the functionality in this function
        return
    endif

    let prefix = a:0 ? a:1 : gettabvar(tabpagenr(), '_tab_prefix', v:none)

    " Checking whether or not the prefix is necessary here because the
    " autocommand is not just triggered when a tab is created, but any
    " time that it is entered.
    if prefix is# v:none && a:prompt
        let prefix = input('Enter tab name: ')

        if empty(prefix)
            let prefix = v:none
        endif
    endif

    if prefix isnot# v:none
        call settabvar(tabpagenr(), '_tab_prefix', prefix)
    endif
endfu

fu! tab#add_buffer(tabnr) " {{{1
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

fu! tab#remove_buffer(tabnr) " {{{1
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

fu! tab#remove_buffers() " {{{1
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

fu! tab#clear_hidden() " {{{1
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

fu! tab#ls(bang, print) " {{{1
    let t:tab_ls_bang = a:bang
    let tabid = s:get_tabid(tabpagenr())
    let buf_list = []

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

                call add(buf_list, s:format_buf_str(tabid, bufnr))
            endfor
        endfor
    else
        let bufnrs = map(keys(g:_tab_set[tabid]), 'str2nr(v:val)')

        for bufnr in bufnrs
            if buflisted(bufnr) == 0
                unlet g:_tab_set[tabid][bufnr]
                continue
            endif

            call add(buf_list, s:format_buf_str(tabid, bufnr))
        endfor
    endif

    if a:print is# v:true
        echo join(buf_list, "\n")
    else
        return buf_list
    endif
endfu

fu! tab#wrap_fzf(bang) " {{{1
    if exists('*fzf#wrap') && executable('fzf')
        let action_map = {}

        if exists('g:fzf_action')
            let action_map = deepcopy(g:fzf_action)
        else
            " These are the default extra key bindings
            let action_map = {
                \ 'ctrl-t': 'tab split',
                \ 'ctrl-x': 'split',
                \ 'ctrl-v': 'vsplit',
            \ }
        endif

        try
            let g:fzf_action = {
                \ 'enter': function('s:edit'),
                \ 'ctrl-t': function('s:edit_tab'),
                \ 'ctrl-x': function('s:edit_split'),
                \ 'ctrl-v': function('s:edit_vert'),
                \ 'ctrl-d': function('s:wipe_buf'),
            \ }

            call fzf#run(fzf#wrap(fzf#vim#with_preview({
                \ 'source': tab#ls(a:bang, v:false),
                \ 'options': '--layout=reverse --multi --bind ctrl-a:select-all',
            \ })))
        finally
            let g:fzf_action = action_map
        endtry
    else
        call tab#ls(a:bang, v:true)
    endif
endfu

fu! s:get_tabid(...) " {{{1
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

fu! s:delete_bufs(tabid, ...) abort " {{{1
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

fu! s:get_tab_name(tabnr, focused) abort " {{{1
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

fu! s:bufnr(buf_str) " {{{1
    " Given a buffer string like:
    "   [X] buffer_name
    " return the buffer number, in this case 'X'.
    return matchstr(a:buf_str, '\[\zs[0-9]*\ze\]')
endfu

fu! s:edit(choice) " {{{1
    " Only support a single entry here
    if len(a:choice)
        silent! exe 'b ' .. s:bufnr(a:choice[0])
    endif
endfu

fu! s:edit_tab(choices) " {{{1
    for choice in a:choices
        silent! exe 'tab sb ' .. s:bufnr(choice)
    endfor
endfu

fu! s:edit_vert(choices) " {{{1
    for choice in a:choices
        silent! exe 'vert sb ' .. s:bufnr(choice)
    endfor
endfu

fu! s:edit_split(choices) " {{{1
    for choice in a:choices
        silent! exe 'sb ' .. s:bufnr(choice)
    endfor
endfu
fu! s:wipe_buf(choices) " {{{1
    for choice in a:choices
        silent! exe 'bwipeout ' .. s:bufnr(choice)
    endfor

    if exists('s:tab_ls_bang')
        call tab#wrap_fzf(t:tab_ls_bang)
    else
        call tab#wrap_fzf(0)
    endif
endfu

fu! s:format_buf_str(tabid, bufnr)
    let modified = getbufinfo(a:bufnr)[0].changed ? '*' : ''
    return '[' .. a:bufnr .. '] ' .. modified .. g:_tab_set[a:tabid][a:bufnr]
endfu
