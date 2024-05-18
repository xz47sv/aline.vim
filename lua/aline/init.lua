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
    __index = function(_, k) return M.lua_builtin[k] or M.vim_builtin[k] end,
})

return M
