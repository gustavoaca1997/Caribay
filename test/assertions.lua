local M = {}
M.contains_error = function(state, arguments)
    local expectedMsg, toCall = table.unpack(arguments)

    local ok, errMsg = pcall(toCall, table.unpack(arguments, 3))
    if ok then
        return false
    else
        local pos = string.find( errMsg, expectedMsg )
        if pos then
            return true
        else
            error(errMsg)
        end
    end
end

return M