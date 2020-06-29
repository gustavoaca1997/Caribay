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

local function traverse(currExpected, currOutput)
    if  not currOutput or
        currExpected.tag ~= currOutput.tag or 
        #currExpected ~= #currOutput
    then
        return false
    else
        local ret = true
        for i, expChild in ipairs(currExpected) do
            local outChild = currOutput[i]
            ret = ret and traverse(expChild, outChild)
        end
        return ret
    end
end

M.same_ast = function(state, arguments)
    --[[
        Checks both AST are the same except for the `pos` field.
    ]]
    local expectedAST, outputAST = table.unpack(arguments)
    return traverse(expectedAST, outputAST)
end

return M