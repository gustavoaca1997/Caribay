-- Sub annotators
local sub_annotator = {}
----------------------------------------------------------------------------
--------------------Auxiliar functions for terminals------------------------
----------------------------------------------------------------------------
local terminal_tags = {
    lex_sym = true,
    literal = true,
    keyword = true,
    class = true,
    any = true,
}

local function is_terminal(node)
    return terminal_tags[node.tag]
end
----------------------------------------------------------------------------
----------------------------------Set Class---------------------------------
----------------------------------------------------------------------------
local Set = {}

function Set:new(set)
    set = set or {}
    -- Inherit form `Set`
    self.__index = self
    setmetatable(set, self)
    return set
end

function Set:copy()
    local set = Set:new{}
    for k, v in pairs(self) do
        set[k] = v
    end
    return set
end

function Set:is_same(set1)
    local ret = true
    for k in pairs(self) do
        ret = ret and set1[k]
    end
    for k in pairs(set1) do
        ret = ret and self[k]
    end
    return ret
end

function Set:add(key)
    local set = self:copy()
    set[key] = true
    return set
end

function Set:rm(key)
    local set = self:copy()
    set[key] = nil
    return set
end

function Set:union(set1)
    local set = self:copy()
    for k, v in pairs(set1) do
        set[k] = set[k] or v
    end
    return set
end

----------------------------------------------------------------------------
----------------------------Annotator Constructors--------------------------
----------------------------------------------------------------------------
local Annotator = {}

function Annotator:new(ast, syms)
    --[[
        `ast`:  Abstract Syntactic Tree from the parser.
        `syms`: Dictionary of symbols objects from the generator.
    ]]
    local obj = {
        ast = assert(ast),
        syms = assert(syms),
        first = {},
        follow = {},
    }

    -- Inherit form `Annotator`
    self.__index = self
    setmetatable(obj, self)
    return obj
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

function Annotator:get_seq_first(exps)
    if not exps or #exps == 0 then
        return { ['%e'] = true }
    end
    local fst_elem = exps[1]
    local fst_elem_first_set = self:get_first(assert(fst_elem))
    if not fst_elem_first_set['%e'] then
        return fst_elem_first_set
    else
        local sub_first = self:get_seq_first{table.unpack(exps, 2)}
        return fst_elem_first_set:rm('%e'):union(sub_first)
    end
end

function Annotator:get_first(exp)
    if exp.tag == 'literal' then
        return Set:new{ ["'" .. exp[1] .. "'"] = true }

    elseif exp.tag == 'keyword' then
        return Set:new{ ["`" .. exp[1] .. "`"] = true }

    elseif is_terminal(exp) then
        return Set:new{ [exp[1]] = true}
        
    elseif exp.tag == 'syn_sym' then
        return self.first[exp[1]]

    elseif exp.tag == 'ord_exp' then
        local ret = Set:new{}
        for _, sub_exp in ipairs(exp) do
            ret = ret:union(self:get_first(assert(sub_exp)))
        end
        return ret

    elseif exp.tag == 'seq_exp' then
        return self:get_seq_first(exp)

    elseif exp.tag == 'star_exp' or exp.tag == 'opt_exp' then
        local sub_first = self:get_first(assert(exp[1]))
        return sub_first:add('%e')

    elseif exp.tag == 'rep_exp' then
        return self:get_first(assert(exp[1]))

    elseif exp.tag == 'empty' then
        return Set:new{ ['%e'] = true }

    elseif exp.tag == 'action' or exp.tag == 'group' then
        return self:get_first(assert(exp[1]))

    else
        return Set:new{ ['%e'] = true }
    end
end

function Annotator:compute_all_first()
    -- Initialize FIRST for each symbol.
    for sym_str, sym in pairs(self.syms) do
        if sym:is_lex() then
            self.first[sym_str] = Set:new{ [sym_str] = true }
        else
            self.first[sym_str] = Set:new{}
        end
    end

    local first_done = false
    while not first_done do
        first_done = true
        -- For each rule, compute FIRST
        for idx, rule in pairs(self.ast) do
            local sym_str = rule[1][1]
            local sym = self.syms[sym_str]
            
            if sym:is_syn() then
                local prev = self.first[sym_str]:copy()
                self.first[sym_str] = assert(self:get_first(assert(rule[2])))
                first_done = first_done and prev:is_same(self.first[sym_str])
            end
        end
    end
end

return {
    annotate = function(ast, syms)
        local annot = Annotator:new(ast, syms)
        annot:compute_all_first()
        return annot
    end,
}