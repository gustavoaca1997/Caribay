
-- Symbol class
local Symbol = {
    is_fragment = false,
    is_keyword = false,
    is_skippable = false,
    rule_no = 0,
}

function Symbol:is_lex()
    return self.type == 'lex'
end

function Symbol:is_syn()
    return self.type == 'syn'
end

function Symbol:new(sym_str, type, is_fragment, is_keyword, is_skippable, rule_no)
    local obj = {
        sym_str = sym_str,
        type = type,
        is_fragment = is_fragment,
        is_keyword = is_keyword,
        is_skippable = is_skippable,
        rule_no = rule_no,
    }
    self.__index = self
    setmetatable(obj, self)
    return obj
end

return Symbol