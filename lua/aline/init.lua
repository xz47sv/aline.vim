local fn = vim.fn

local M = {
    setup = fn['aline#setup'],
    escape = fn['aline#escape'],
    lua_builtin = require('aline/builtin'),
    vim_builtin = {},
}

for _, k in ipairs(fn['aline#builtin#list']())
do
    M.vim_builtin[k] = fn['aline#builtin#' .. k]
end

M.builtin = setmetatable({}, {
    __index = function(_, k)
        if M.lua_builtin[k]
        then
            return M.lua_builtin[k]
        else
            return M.vim_builtin[k]
        end
    end,
})

return M
