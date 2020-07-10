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

local function copy_set_table(t)
    local ret = {}
    for k, v in pairs(t) do
        ret[k] = v:copy()
    end
    return ret
end

local function is_same_set_table(t1, t2)
    local ret = true
    for k, v1 in pairs(t1) do
        local v2 = t2[k]
        ret = ret and v1:is_same(v2)
    end
    return ret
end
----------------------------------------------------------------------------
----------------------------Annotator Constructors--------------------------
----------------------------------------------------------------------------
local Annotator = {}

function Annotator:new(ast, syms, init)
    --[[
        `ast`:  Abstract Syntactic Tree from the parser.
        `syms`: Dictionary of symbols objects from the generator.
    ]]
    local obj = {
        ast = assert(ast),
        syms = assert(syms),
        init = assert(init),
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

----------------------------------------------------------------------------
----------------------------------------------------------------------------
local END_TOKEN = '__$';

function Annotator:compute_seq_follow(exps, flw)
    if not exps or #exps == 0 then
        return
    end
    local last_elem = exps[#exps]
    self:compute_follow(last_elem, flw)
    local flw1 = self:get_first(last_elem)
    if flw1['%e'] then
        flw1 = flw1:union(flw)
        flw1['%e'] = nil
    end
    self:compute_seq_follow({table.unpack(exps, 1, #exps-1)}, flw1)
end

function Annotator:compute_follow(exp, flw)
    if exp.tag == 'syn_sym' then
        local syn = exp[1]
        local union = self.follow[syn]:union(flw)
        union['%e'] = nil
        self.follow[syn] = union

    elseif exp.tag == 'ord_exp' then
        for _, sub_exp in ipairs(exp) do
            self:compute_follow(sub_exp, flw)
        end

    elseif exp.tag == 'seq_exp' then
        self:compute_seq_follow(exp, flw)

    elseif exp.tag == 'opt_exp' then
        self:compute_follow(exp[1], flw)

    elseif exp.tag == 'rep_exp' or exp.tag == 'star_exp' then
        local exp_first = self:get_first(exp[1])
        self:compute_follow(exp[1], flw:union(exp_first))

    elseif exp.tag == 'action' or exp.tag == 'group' then
        self:compute_follow(exp[1], flw)
    end
end


function Annotator:compute_all_follow()
    -- Initialize FOLLOW sets
    local init_str = self.init
    local init_sym = self.syms[init_str]
    for sym_str, sym in pairs(self.syms) do
        if sym_str ~= init_str and sym:is_syn() then
            self.follow[sym_str] = Set:new{}
        end
    end
    self.follow[init_str] = init_sym:is_syn() and Set:new{
        [END_TOKEN] = true
    } or nil

    local follow_done = false
    while not follow_done do
        local prev_follow = copy_set_table(self.follow)
        -- For each rule compute FOLLOW set
        for idx, rule in ipairs(self.ast) do
            local lhs = rule[1]
            local sym_str = lhs[1]
            local sym = self.syms[sym_str]
            if sym:is_syn() then
                local rhs = rule[2]
                self:compute_follow(rhs, self.follow[sym_str])
            end
        end

        follow_done = is_same_set_table(prev_follow, self.follow)
    end
end

return {
    annotate = function(ast, syms, init)
        local annot = Annotator:new(ast, syms, init)
        annot:compute_all_first()
        annot:compute_all_follow()
        return annot
    end,
    END_TOKEN = END_TOKEN,
}