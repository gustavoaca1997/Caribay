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
        currExpected.skippable ~= currOutput.skippable or
        currExpected.label ~= currOutput.label or
        currExpected.action ~= currOutput.action or
        currExpected.group ~= currOutput.group or
        currExpected.captured ~= currOutput.captured or
        currExpected.fragment ~= currOutput.fragment or
        currExpected.keyword ~= currOutput.keyword or
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

M.has_lab = function(state, arguments)
    local parser, input, expected_lab, expected_pos = table.unpack(arguments)
    local ou, lab, pos = parser:match(input)
    if out then
        error(input .. ": Not error thrown")
    elseif expected_lab ~= lab then
        error(input .. ": Expected label " .. expected_lab .. " but got " .. lab)
    elseif expected_pos and expected_pos ~= pos then
        error(input .. ": Expected position " .. expected_pos .. " but got " .. pos)
    end
    return true
end

return M