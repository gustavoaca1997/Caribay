--[[
    This module helps Generator class to annotate its grammar.
]]

local Set = require"Set"

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
----------------------------------------------------------------------------

local function token_to_key(exp)
    --[[
        Transforms AST token into a key 
    ]]
    if exp.tag == 'literal' then
        return "'" .. exp[1] .. "'"

    elseif exp.tag == 'keyword' then
        return "`" .. exp[1] .. "`"

    elseif exp.tag == 'lex_sym' then
        return exp[1]
    end
end

----------------------------------------------------------------------------
----------------------------Annotator Constructors--------------------------
----------------------------------------------------------------------------
local Annotator = {}

function Annotator:new(ast, syms, init)
    --[[
        This class helps to run Algorithm Unique

        `ast`:  Abstract Syntactic Tree from the parser.
        `syms`: Dictionary of symbols objects from the generator.
    ]]
    local obj = {
        ast = assert(ast),
        syms = assert(syms),
        init = assert(init),
        first = {},
        follow = {},
        context = {},
        last = {},
        ocs = {},   -- ocurrences
        is_uni_token_memo = {},  -- cache of is_uni_token
    }

    -- Inherit form `Annotator`
    self.__index = self
    setmetatable(obj, self)
    return obj
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------
local END_TOKEN = '__$';

function Annotator:get_tokens_set(exp, set_type)
    --[[
        This functions works for computing either FIRST sets or
        LAST sets, where `set_type` is either 'first' or 'last'.
    ]]
    local tokens_set = set_type == 'first' and self.first or self.last;

    if exp.tag == 'literal' then
        return Set:new{ ["'" .. exp[1] .. "'"] = true }

    elseif exp.tag == 'keyword' then
        return Set:new{ ["`" .. exp[1] .. "`"] = true }

    elseif is_terminal(exp) then
        return Set:new{ [exp[1]] = true}
        
    elseif exp.tag == 'syn_sym' then
        return tokens_set[exp[1]]

    elseif exp.tag == 'ord_exp' then
        return self:get_ord_tokens_set(exp, set_type)

    elseif exp.tag == 'seq_exp' then
        if set_type == 'first' then
            return self:get_seq_first(exp)
        else
            return self:get_seq_last(exp)
        end

    elseif exp.tag == 'star_exp' or exp.tag == 'opt_exp' then
        local sub = self:get_tokens_set(exp[1], set_type)
        return sub:add('%e')

    elseif exp.tag == 'rep_exp' then
        return self:get_tokens_set(exp[1], set_type)

    elseif exp.tag == 'empty' then
        return Set:new{ ['%e'] = true }

    elseif exp.tag == 'action' or exp.tag == 'group' then
        return self:get_tokens_set(exp[1], set_type)

    else
        return Set:new{ ['%e'] = true }
    end
end

function Annotator:get_ord_tokens_set(exp, set_type)
    local ret = Set:new{}
    for _, sub_exp in ipairs(exp) do
        ret = ret:union(self:get_tokens_set(sub_exp, set_type))
    end
    return ret
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

function Annotator:get_ord_first(exp)
    return self:get_ord_tokens_set(exp, 'first')
end

function Annotator:get_first(exp)
    return self:get_tokens_set(exp, 'first')
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

    elseif exp.tag == 'action' or exp.tag == 'group' or exp.tag == 'throw_exp' then
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
        local prev_follow = Set.copy_set_table(self.follow)
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

        follow_done = Set.is_same_set_table(prev_follow, self.follow)
    end
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

function Annotator:get_seq_last(exps)
    if not exps or #exps == 0 then
        return { ['%e'] = true }
    end
    local lst_elem = exps[#exps]
    local lst_elem_last_set = self:get_last(lst_elem)
    if not lst_elem_last_set['%e'] then
        return lst_elem_last_set
    else
        local sub_last = self:get_seq_last{table.unpack(exps, 1, #exps-1)}
        return lst_elem_last_set:rm('%e'):union(sub_last)
    end
end

function Annotator:get_ord_last(exp)
    return self:get_ord_tokens_set(exp, 'last')
end

function Annotator:get_last(exp)
    return self:get_tokens_set(exp, 'last')
end

function Annotator:compute_all_last()
    -- Initialize LAST for each symbol.
    for sym_str, sym in pairs(self.syms) do
        if sym:is_lex() then
            self.last[sym_str] = Set:new{ [sym_str] = true }
        else
            self.last[sym_str] = Set:new{}
        end
    end

    local last_done = false
    while not last_done do
        last_done = true
        -- For each rule, compute LAST
        for idx, rule in pairs(self.ast) do
            local sym_str = rule[1][1]
            local sym = self.syms[sym_str]
            
            if sym:is_syn() then
                local prev = self.last[sym_str]:copy()
                self.last[sym_str] = self:get_last(rule[2])
                last_done = last_done and prev:is_same(self.last[sym_str])
            end
        end
    end
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

function Annotator:compute_seq_context(exps, bfr)
    if not exps or #exps == 0 then
        return
    end
    local first_elem = exps[1]
    self:compute_context(first_elem, bfr)
    local bfr1 = self:get_last(first_elem)
    if bfr1['%e'] then
        bfr1 = bfr1:union(bfr)
        bfr1['%e'] = nil
    end
    self:compute_seq_context({table.unpack(exps, 2, #exps)}, bfr1)
end

function Annotator:compute_context(exp, bfr)
    if exp.tag == 'syn_sym' then
        local non_terminal = exp[1]
        local union = self.context[non_terminal]:union_without_key(bfr, '%e')
        self.context[non_terminal] = union

    elseif exp.tag == 'lex_sym' or exp.tag == 'literal' or exp.tag == 'keyword' then
        local key = token_to_key(exp)

        -- Position 0 has the global CONTEXT set
        self.context[key] = self.context[key] or Set:new{}
        self.context[key][0] = self.context[key][0] or Set:new{}
        
        local union = self.context[key][0]:union_without_key(bfr, '%e')
        self.context[key][0] = union

        local pos = exp.pos
        self.context[key][pos] = self.context[key][pos] or Set:new{}
        local union = self.context[key][pos]:union_without_key(bfr, '%e')
        self.context[key][pos] = union

    elseif exp.tag == 'ord_exp' then
        for _, sub_exp in ipairs(exp) do
            self:compute_context(sub_exp, bfr)
        end

    elseif exp.tag == 'seq_exp' then
        self:compute_seq_context(exp, bfr)

    elseif exp.tag == 'opt_exp' then
        self:compute_context(exp[1], bfr)

    elseif exp.tag == 'rep_exp' or exp.tag == 'star_exp' then
        local exp_context = self:get_last(exp[1])
        self:compute_context(exp[1], bfr:union(exp_context))

    elseif exp.tag == 'action' or exp.tag == 'group' or exp.tag == 'throw_exp' then
        self:compute_context(exp[1], bfr)

    end
end


function Annotator:compute_all_context()
    -- Initialize CONTEXT sets
    local init_str = self.init
    local init_sym = self.syms[init_str]
    for sym_str, sym in pairs(self.syms) do
        local new_set
        if sym_str ~= init_str then
            new_set = Set:new{}
        else
            new_set = Set:new{
                [END_TOKEN] = true
            }
        end

        -- Lexical non-terminal will have many CONTEXT sets. In the position 0
        -- will be the globar CONTEXT sets, and in position `pos` != 0, will be the
        -- local CONTEXT set for the instance in that position in the grammar.
        if sym:is_syn() then
            self.context[sym_str] = new_set
        else
            self.context[sym_str] = Set:new{}
            self.context[sym_str][0] = new_set
        end
    end

    local context_done = false
    while not context_done do
        local prev_context = Set.copy_set_table(self.context)
        -- For each rule compute CONTEXT set
        for idx, rule in ipairs(self.ast) do
            local lhs = rule[1]
            local sym_str = lhs[1]
            local sym = self.syms[sym_str]
            local rhs = rule[2]
            local bfr = sym:is_syn() and self.context[sym_str] or self.context[sym_str][0]
            self:compute_context(rhs, bfr)
        end

        context_done = Set.is_same_set_table(prev_context, self.context)
    end
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

function Annotator:compute_terminal_ocs(exp)
    local key = token_to_key(exp)

    if key then
        self.ocs[key] = (self.ocs[key] or 0) + 1
    else
        for _, sub_exp in ipairs(exp) do
            self:compute_terminal_ocs(sub_exp)
        end
    end
end

function Annotator:compute_all_terminal_ocs(exp)
    -- For each rule, compute ocs
    for idx, rule in pairs(self.ast) do
        local sym_str = rule[1][1]
        local sym = self.syms[sym_str]
        
        if sym:is_syn() then
            self:compute_terminal_ocs(rule[2])
        end
    end
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

function Annotator:has_unique_context(token_key, pos)
    if not self.use_unique_context then
        return false
    end
    local curr_context = self.context[token_key][pos]
    local ret = true
    for pos1, context in pairs(self.context[token_key]) do
        if pos1 > 0 then -- Position 0 has global context
            ret = ret and (pos1 == pos or context:disjoint(curr_context))
        end
    end
    return ret
end

function Annotator:is_uni_token(token_key, pos)
    --[[
        A lexical non-terminal A is unique when it appears in the right-hand
        side of only one syntactical rule, and just once.
    ]]
    
    if not self.is_uni_token_memo[assert(token_key)] then
        self.is_uni_token_memo[token_key] = {}
    end
    
    if not self.ocs[token_key] then
        return false

    elseif self.is_uni_token_memo[token_key][assert(pos)] ~= nil then -- memoization
        return self.is_uni_token_memo[token_key][pos]
    end

    -- Count number of keys
    local count = self.ocs[token_key]

    -- It's unique token if there is only one LHS that uses it or if it has
    -- unique context.
    local ret = token_key ~= 'SKIP' and token_key ~= 'COMMENT' and count == 1 or
                self:has_unique_context(token_key, pos)
    self.is_uni_token_memo[token_key][pos] = ret
    return ret
end

function Annotator:calck(ast_exp, flw, opt)
    --[[
        It is used to update the FOLLOW set associated with a
        parsing expression.
    ]]

    local first
    if not opt then
        first = self:get_first(ast_exp)
    elseif opt == 'seq' then
        first = self:get_seq_first(ast_exp)
    elseif opt == 'ord' then
        first = self:get_ord_first(ast_exp)
    end

    if flw['%e'] then
        first['%e'] = nil
        return first:union(flw)
    else
        return first
    end
end

function Annotator:match_uni(ast_exp)
    --[[
        Determines whether a parsing expression p matches
        at least one unique lexical non-terminal or not.
    ]]
    
    local tag = ast_exp.tag
    local key = token_to_key(ast_exp)
    if key then
        return self:is_uni_token(key, assert(ast_exp.pos))
    elseif tag == 'seq_exp' then
        local ret = false
        for idx, sub_exp in ipairs(ast_exp) do
            ret = ret or self:match_uni(sub_exp)
            if ret then break end
        end
        return ret
    elseif tag == 'ord_exp' then
        local ret = true
        for idx, sub_exp in ipairs(ast_exp) do
            ret = ret and self:match_uni(sub_exp)
            if not ret then break end
        end
        return ret
    elseif tag == 'rep_exp' then
        return self:match_uni(ast_exp[1])
    else
        return false
    end
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------


return {
    annotate = function(ast, syms, init, use_unique_context)
        local annot = Annotator:new(ast, syms, init)
        annot:compute_all_first()
        annot:compute_all_follow()
        annot:compute_all_terminal_ocs()

        if use_unique_context then 
            annot:compute_all_last()
            annot:compute_all_context() 
        end
        annot.use_unique_context = use_unique_context

        return annot
    end,
    END_TOKEN = END_TOKEN,
    token_to_key = token_to_key,
}