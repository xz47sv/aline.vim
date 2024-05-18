-- SPDX-FileCopyrightText: 2024 Ash <contact@ash.fail>
-- SPDX-License-Identifier: MIT

-- MIT License

--  Copyright (c) 2024 Ash contact@ash.fail

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice (including the next
-- paragraph) shall be included in all copies or substantial portions of the
-- Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.

local M = {}

local api = vim.api
local b = vim.b
local diagnostic = vim.diagnostic
local fn = vim.fn
local lsp = vim.lsp

-- mimics s:call_builtin in autoload/aline/builtin.vim
local make_builtin = function(callback)
    return function(options)
        options = options or {}

        if options.enabled and not options.enabled() then return nil end

        local res = callback(options)
        if res and res.text
        then
            for _, v in ipairs({ 'highlight', 'left_sep', 'right_sep' })
            do
                res[v] = res[v] or options[v]
            end

            return res
        end
    end
end

for _, v in ipairs({ 'error', 'warn', 'info', 'hint' })
do
    local icon = v:sub(1, 1):upper()
    local severity = diagnostic.severity[v:upper()]

    M['diagnostic_' .. v] = make_builtin(function(options)
        local n = #diagnostic.get(
            api.nvim_get_current_buf(), { severity = severity }
        )

        if n > 0 then return { text = (options.icon or icon) .. n } end
    end)
end

for _, v in ipairs({
    { 'added', '+' }, { 'changed', '~' }, { 'removed', '-' },
})
do
    M['git_' .. v[1]] = make_builtin(function(options)
        local status = (b.gitsigns_status_dict or {})[v[1]]
        if status and status ~= 0
        then
            return { text = options.icon or v[2] .. status }
        end
    end)
end

for _, v in ipairs({ 'head', 'root', 'gitdir' })
do
    M['git_' .. v] = make_builtin(function()
        return { text = (b.gitsigns_status_dict or {})[v] }
    end)
end

local ok, devicons = pcall(require, 'nvim-web-devicons')
if ok
then
    M.icon = make_builtin(function()
        return { text = devicons.get_icon(fn.expand('%t'), b.filetype) }
    end)
end

local lsp_client_names = function()
    return vim.tbl_map(
        function(v) return v.name end,
        lsp.get_active_clients({ bufnr = api.nvim_get_current_buf() })
    )
end

local clients_autocmd_exists = false
-- XXX: maybe get the names of attached null-ls sources and show them too
M.lsp_clients = make_builtin(function(options)
    if not clients_autocmd_exists
    then
        local group = api.nvim_create_augroup('aline', { clear = false })
        api.nvim_create_autocmd('BufEnter', {
            callback = function()
                b.lsp_client_names = lsp_client_names()
                vim.cmd.redrawstatus()
            end,
            group = group,
        })
        api.nvim_create_autocmd('User', {
            pattern = { 'LspAttach', 'LspDetach' },
            callback = function()
                b.lsp_client_names = lsp_client_names()
                vim.cmd.redrawstatus()
            end,
            group = group,
        })

        clients_autocmd_exists = true
        b.lsp_client_names = lsp_client_names()
    end

    local clients = b.lsp_client_names
    options = vim.tbl_extend(
        'force', { exclude = {}, icon = '', separator = ', ' }, options
    )

    if not vim.tbl_isempty(options.exclude)
    then
        clients = vim.tbl_filter(
            function(v)
                return not vim.tbl_contains(options.exclude, v)
            end,
            clients or {}
        )
    end

    return { text = options.icon .. table.concat(clients, options.separator) }
end)

local lsp_progress = function()
    local progress = lsp.util.get_progress_messages()[1]
    if not (
            progress
            and not vim.tbl_isempty(
                lsp.get_active_clients({
                    bufnr = api.nvim_get_current_buf(),
                    name = progress.name,
                })
            )
        )
    then
        return nil
    else
        return progress
    end
end

local progress_autocmd_exists = false
M.lsp_progress = make_builtin(function(options)
    if not progress_autocmd_exists
    then
        local group = api.nvim_create_augroup('aline', { clear = false })
        api.nvim_create_autocmd('BufEnter', {
            callback = function()
                b.lsp_progress = lsp_progress()
                vim.cmd.redrawstatus()
            end,
            group = group,
        })

        api.nvim_create_autocmd('User', {
            pattern = { 'LspProgressUpdate', 'LspRequest' },
            callback = function()
                b.lsp_progress = lsp_progress()
                vim.cmd.redrawstatus()
            end,
            group = group,
        })

        progress_autocmd_exists = true
        b.lsp_progress = lsp_progress()
    end

    local progress = b.lsp_progress
    if not progress then return nil end

    local title = progress.title and progress.title .. ' ' or ''
    local msg = progress.message and progress.message .. ' ' or ''
    local percentage = progress.percentage
    if not percentage then return nil end

    return {
        text = (options.format or '%s%s(%s%%)'):format(
            title, msg, percentage
        ),
    }
end)

return M
