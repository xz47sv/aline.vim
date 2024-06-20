"SPDX-FileCopyrightText: 2024 Ash <contact@ash.fail>
"SPDX-License-Identifier: MIT

"MIT License

" Copyright (c) 2024 Ash contact@ash.fail

"Permission is hereby granted, free of charge, to any person obtaining a copy
"of this software and associated documentation files (the "Software"), to deal
"in the Software without restriction, including without limitation the rights
"to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"copies of the Software, and to permit persons to whom the Software is
"furnished to do so, subject to the following conditions:

"The above copyright notice and this permission notice (including the next
"paragraph) shall be included in all copies or substantial portions of the
"Software.

"THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
"SOFTWARE.

" this exists because you cannot compare v:null with dictionaries and boolean
" rules in vimscript are funky
function! s:is_null(v) abort
    return type(a:v) == type(v:null)
endfunction

function! aline#_validate(name, v, expect) abort
    let types = [
        \'number', 'string', 'funcref', 'list', 'dictionary', 'float',
        \'boolean', 'null', v:null, v:null, 'blob',
    \]

    let expect = type(a:expect) == v:t_list ? a:expect : [a:expect]
    let match = v:false
    for e in expect
        if (e == type(a:v))
            let match = v:true
            break
        endif
    endfor

    if !match
        throw printf(
            \"%s: expected %s, got '%s'",
            \a:name,
            \string(map(expect, { _, v -> types[v] })),
            \types[type(a:v)],
        \)
    endif
endfunction

function! aline#escape(text) abort
    call aline#_validate('text', a:text, v:t_string)
    return substitute(a:text, '%', '%%', 'g')
endfunction

function! s:make_highlight(hl) abort
    let hl = copy(a:hl)

    if s:is_null(hl) || type(hl) == v:t_string
        return hl
    endif

    call aline#_validate('hl', hl, v:t_dict)

    let bg = get(hl, 'bg', 'NONE')
    let fg = get(hl, 'fg', 'NONE')
    let attrs = join(sort(get(hl, 'attrs', [])), ',')
    if empty(attrs)
        let attrs = 'NONE'
    endif

    let name = substitute(
        \printf('Aline_%s_%s_%s', bg, fg, attrs), '[,#]', '', 'g'
    \)

    if !hlexists(name)
        execute printf(
            \'hi! %s guibg=%s guifg=%s gui=%s cterm=%s',
            \name, bg, fg, attrs, attrs,
        \)
    endif

    return name
endfunction

function! s:make_separator(separator) abort
    let separator = deepcopy(a:separator)

    if s:is_null(separator)
        return v:null
    elseif type(separator) == v:t_string
        return s:make_separator({ 'text': separator })
    endif

    call aline#_validate('separator', separator, v:t_dict)

    if s:is_null(get(separator, 'text', v:null))
        return v:null
    endif

    let separator.text = aline#escape(separator.text)

    if has_key(separator, 'highlight')
        let separator.highlight = s:make_highlight(separator.highlight)
    endif

    return separator
endfunction

function! aline#_eval() abort
    if !has_key(g:, 'actual_curwin')
        let g:actual_curwin = win_getid()
        return '%{%aline#_eval()%}'
    endif

    if g:actual_curwin == win_getid()
        let line = g:aline_config.active
    else
        let line = g:aline_config.inactive
    endif

    let default_hl = '%#' . line.highlight . '#'
    let statusline = default_hl

    let n_sections = len(line.sections)
    for i in range(0, n_sections - 1)
        let section = line.sections[i]

        let n_components = len(section.components)
        for j in range(0, n_components - 1)
            let Component = section.components[j]

            if type(Component) == v:t_func
                let Component = Component()
                if s:is_null(Component)
                    continue
                endif

                " all builtin components return dicts but allow user to just
                " return string
                if type(Component) == v:t_string
                    let Component = { 'text': Component }
                endif
            elseif has_key(Component, 'enabled')
                if !Component.enabled()
                    continue
                endif
            endif

            call aline#_validate(
                \printf('%d.components[%d]', i, j), Component, v:t_dict
            \)

            let text = get(Component, 'text', v:null)
            if s:is_null(text) || len(text) == 0
                continue
            endif

            if !get(Component, 'eval', v:false)
                let text = aline#escape(text)
            endif

            let hl = s:make_highlight(
                \get(Component, 'highlight', get(section, 'highlight', v:null))
            \)

            let left_sep = s:make_separator(
                \get(Component, 'left_sep', section.left_sep)
            \)
            let right_sep = s:make_separator(
                \get(Component, 'right_sep', section.right_sep)
            \)

            if has_key(left_sep, 'highlight')
                let statusline = statusline
                    \. '%#'
                    \. left_sep.highlight
                    \. '#'
                    \. left_sep.text
                    \. default_hl
            else
                let text = left_sep.text . text
            endif

            if !s:is_null(hl)
                let statusline = statusline . '%#' . hl . '#'
            endif

            if has_key(right_sep, 'highlight')
                let statusline = statusline
                    \. text
                    \. '%#'
                    \. right_sep.highlight
                    \. '#'
                    \. right_sep.text
            else
                let statusline = statusline . text . right_sep.text
            endif

            if !s:is_null(hl) || has_key(right_sep, 'highlight')
                let statusline = statusline . default_hl
            endif
        endfor

        if i != n_sections - 1
            let statusline = statusline . '%='
        endif
    endfor

    return statusline
endfunction

function! s:setup_component(component) abort
    if type(a:component) == v:t_func || type(a:component) == v:t_dict
        return a:component
    elseif type(a:component) == v:t_string
        return s:setup_component([a:component])
    endif

    call aline#_validate('component', a:component, v:t_list)

    let Component = get(g:aline_components, a:component[0], v:null)
    if s:is_null(Component)
        throw 'aline.vim: invalid Component `' . a:component[0] . '`'
    endif

    let options = get(a:component, 1, {})
    if type(Component) == v:t_func
        return empty(options) ? Component : { -> Component(options) }
    elseif type(Component) == v:t_string
        return extend({ 'text': Component, 'eval': v:true }, options, 'keep')
    endif

    return Component
endfunction

function! s:setup_section(section) abort
    if type(a:section) == v:t_list
        return s:setup_section({ 'components': a:section })
    endif

    if has_key(a:section, 'highlight')
        let a:section.highlight = s:make_highlight(a:section.highlight)
    endif

    call map(a:section.components, { _, c -> s:setup_component(c) })

    return a:section
endfunction

function! s:setup_separators(child, parent) abort
    for k in ['left_sep', 'right_sep']
        let a:child[k] = get(a:child, k, a:parent[k])
    endfor

    return a:child
endfunction

" TODO:
"   - docs
"   - more validation
"   - maybe ability to add special rules for filetypes, e.g. for terminal, help
"   - support for git in vim (fugitive probably)
function! aline#setup(...) abort
    " setup builtin components
    let g:aline_components = get(g:, 'aline_components', {})

    if has('nvim') || has('lua')
        for [name, Component] in items(v:lua.require('aline').lua_builtin)
            let g:aline_components[name] = get(
                \g:aline_components, name, Component
            \)
        endfor
    endif

    for name in aline#builtin#list()
        let g:aline_components[name] = get(
            \g:aline_components, name, function('aline#builtin#' . name)
        \)
    endfor

    let g:aline_config = extend(
        \{
            \'left_sep': ' ',
            \'right_sep': ' ',
            \'active': {
                \'highlight': { 'bg': '#303030', 'fg': '#ffffff' },
                \'sections': [
                    \[
                        \['mode', {
                            \'attrs': ['bold'],
                            \'n': { 'bg': '#afdf00', 'fg': '#005f00' },
                            \'i': { 'bg': '#ffffff', 'fg': '#005f5f' },
                            \'v': { 'bg': '#ffaf00', 'fg': '#000000' },
                            \'s': { 'bg': '#ffaf00', 'fg': '#000000' },
                            \'r': { 'bg': '#df0000', 'fg': '#ffffff' },
                            \'c': { 'bg': '#b58900', 'fg': '#262626' },
                        \}],
                        \['file', {
                            \'highlight': { 'bg': '#4e4e4e', 'fg': '#ffffff' }
                        \}],
                        \['modified', {
                            \'left_sep': '',
                            \'highlight': { 'bg': '#4e4e4e', 'fg': '#ffffff' }
                        \}],
                    \],
                    \[
                        \['fileformat', { 'right_sep': ' |' }],
                        \['encoding', { 'right_sep': ' |' }],
                        \'filetype',
                        \['percentage', {
                            \'highlight': { 'bg': '#4e4e4e', 'fg': '#ffffff' }
                        \}],
                        \['position', {
                            \'highlight': { 'bg': '#585858', 'fg': '#ffffff' }
                        \}],
                    \],
                \]
            \},
            \'inactive': {
                \'right_sep': '',
                \'highlight': { 'bg': '#262626', 'fg': '#bcbcbc' },
                \'sections': [['file', 'modified']],
            \},
        \},
        \get(a:, 1, get(g:, 'aline_config', {}))
    \)

    for k in ['active', 'inactive']
        if type(g:aline_config[k]) == v:t_list
            let g:aline_config[k] = { 'sections': g:aline_config[k] }
        endif

        let g:aline_config[k].highlight = s:make_highlight(
            \get(
                \g:aline_config[k],
                \'highlight',
                \k ==# 'active' ? 'StatusLine' : 'StatusLineNC'
            \)
        \)

        call s:setup_separators(g:aline_config[k], g:aline_config)

        let g:aline_config[k].sections = map(
            \get(g:aline_config[k], 'sections', []),
            \{ _, s ->
                \s:setup_separators(s:setup_section(s), g:aline_config[k])
            \},
        \)
    endfor

    if has('vim-8.1.1372') || has('nvim-0.5')
        set statusline=%{%aline#_eval()%}
    else
        set statusline=%!aline#_eval()
    endif
endfunction
