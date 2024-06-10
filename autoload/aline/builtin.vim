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

if exists('WebDevIconsGetFileTypeSymbol')
    function! s:icon(_) abort
        return { 'text': WebDevIconsGetFileTypeSymbol() }
    endfunction
else
    function! s:icon(_) abort
        return {}
    endfunction
endif

" options: {
"     max_width: number
" }
function! s:file(options) abort
    let max_width = get(a:options, 'max_width')
    if !max_width
        return { 'text': '%f', 'eval': v:true }
    endif

    let max_width = floor(winwidth(0) / 100.0 * max_width)
    let fname = expand('%:~:.')
    let length = len(fname)
    if length == 0
        return {}
    endif

    let schema = matchstr(fname, '\m^\w\+://')
    let fname = fname[len(schema):]
    let segments = split(fname, '/', 1)
    let is_dir = segments[-1] ==# ''

    if len(segments) <= 1
        return { 'text': schema . fname }
    endif

    " -3/-2 so we skip the tail, if it's a directory we need to skip one more
    " because the last segment is blank
    for i in range(0, len(segments) - (is_dir ? 3 : 2))
        if length <= max_width
            break
        endif

        let segment = segments[i]
        let segments[i] = segment[:(segment[0] ==# '.' ? 1 : 0)]
        let length = length - len(segment) + len(segments[i])
    endfor

    if length > max_width && !empty(schema)
        let length = length - len(schema) + 4
        let schema = schema[0] . '://'
    endif

    if length > max_width
        let fname = segments[-(is_dir ? 2 : 1)]
    else
        let fname = join(segments, '/')
    endif

    return { 'text': schema . fname }
endfunction

function! s:encoding(_) abort
    return { 'text': &encoding }
endfunction

function! s:fileformat(_) abort
    return { 'text': &fileformat }
endfunction

" options: {
"     no_filetype: string (default: 'no ft')
" }
function! s:filetype(options) abort
    return {
        \'text': empty(&filetype)
            \ ? get(a:options, 'no_filetype', 'no ft')
            \ : &filetype
    \}
endfunction

" options: {
"     attrs: string[]
"     [mode]: { 'text': string, 'highlight': string }
" }
function! s:mode(options) abort
    let modes = {
        \'n': 'NORMAL',
        \'no': 'N-PENDING',
        \'i': 'INSERT',
        \'ic': 'INSERT',
        \'t': 'TERMINAL',
        \'v': 'VISUAL',
        \'V': 'V-LINE',
        \'': 'V-BLOCK',
        \'R': 'REPLACE',
        \'Rv': 'V-REPLACE',
        \'s': 'SELECT',
        \'S': 'S-LINE',
        \'': 'S-BLOCK',
        \'c': 'COMMAND',
        \'cv': 'COMMAND',
        \'ce': 'COMMAND',
        \'r': 'PROMPT',
        \'rm': 'MORE',
        \'r?': 'CONFIRM',
        \'!': 'SHELL',
    \}

    let mode = mode()

    " if we don't find the exact mode try to find a similar one
    let opts = get(
        \a:options,
        \mode,
        \get(
            \a:options,
            \get({ '': 's', '': 'v', '!': 'c' }, mode, tolower(mode[0])),
            \{}
        \)
    \)

    if has_key(opts, 'bg') || has_key(opts, 'fg') || has_key(opts, 'attrs')
        let opts = { 'highlight': opts }
    endif

    return {
        \'text': get(opts, 'text', modes[mode]),
        \'highlight': extend(
            \get(opts, 'highlight', {}),
            \{ 'attrs': get(a:options, 'attrs', []) }
        \),
    \}
endfunction

function! s:modified(_) abort
    if &modified
        return { 'text': '[+]' }
    elseif &readonly || !&modifiable
        return { 'text': '[-]' }
    else
        return {}
    endif
endfunction

" options: {
"     pad_zeroes: number | bool (default: 2)
"     bot: string (default: 'Bot')
"     top: string (default: 'Top')
" }
function! s:percentage(options) abort
    let bot = get(a:options, 'bot', 'Bot')
    let top = get(a:options, 'top', 'Top')

    let lnum = line('.')
    let pos = ''
    if top && lnum == 1
        let pos = top
    elseif bot && lnum == line('$')
        let pos = bot
    else
        let pos = lnum * 100 / line('$')
        let pad = get(a:options, 'pad_zeroes', 2)

        if pad
            if type(pad) == v:t_bool
                let pad = 2
            endif
            call aline#_validate('pad_zeroes', pad, v:t_number)

            let pos = printf('%0' . pad . 'd%', pos)
        endif
        let pos = pos . '%'
    endif

    return { 'text': pos }
endfunction

" options: { separator: string (default: ':') }
function! s:position(options) abort
    return {
        \'text': '%l' . aline#escape(get(a:options, 'separator', ':')) . '%v',
        \'eval': v:true,
    \}
endfunction

function! s:truncate(_) abort
    return { 'text': '%<', 'eval': v:true, 'left_sep': '', 'right_sep': '' }
endfunction

function! s:call_builtin(name, options_list) abort
    let options = get(a:options_list, 0, {})

    if !get(options, 'enabled', { -> v:true })()
        return v:null
    endif

    let res = function(a:name)(options)
    for k in ['highlight', 'left_sep', 'right_sep']
        if has_key(options, k) && !has_key(res, k)
            let res[k] = options[k]
        endif
    endfor

    return res
endfunction

let s:builtins = []

" function components
for component in [
        \'icon', 'encoding', 'file', 'fileformat', 'filetype', 'mode',
        \'modified', 'percentage', 'position', 'truncate',
    \]
    call add(s:builtins, component)

    let fn = 'aline#builtin#' . component

    execute 'function! ' . fn . '(...) abort'
        \. printf("\nreturn s:call_builtin('s:%s', a:000)\n", component)
        \. 'endfunction'
endfor

function! aline#builtin#list() abort
    return s:builtins
endfunction
