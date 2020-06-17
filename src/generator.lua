local re = require"relabel"
local lp = require"lpeglabel"
local parser = require"parser"

lp.locale(lp) -- adds locale entries into 'lpeglabel' table
----------------------------------------------------------------------------
----------------------------------------------------------------------------

-- Module to export
local M = {}

-- generators for each kind of node
local generator = {}

----------------------------------------------------------------------------
----------------------------------------------------------------------------

local function get_syms (ast)
    --[[
        From AST, store in the module table the symbols with 
        info about their types and annotations.
    ]]
    local syms = {
        skip = {
            type = 'syn',
            is_fragment = false,
            is_keyword = false,
        },
    }

    for idx, rule in ipairs(ast) do
        local sym = rule[1]
        local type = sym.tag == 'syn_sym' and 'syn' or 'lex'
        local is_fragment = rule.fragment and true or false     -- rule.fragment is "true" or nil
        local is_keyword = rule.keyword and true or false       -- rule.keyword is "true" or nil

        -- Save first symbol as first rule
        if #M.grammar == 0 then
            M.grammar[1] = sym[1]
        end

        -- Save rule
        syms[sym[1]] = {
            type = type,
            is_fragment = is_fragment,
            is_keyword = is_keyword,
            rule_no = idx,
        }
    end
    M.syms = syms
    return M.syms
end

local function to_lpeg(node, sym)
    --[[
        Generates LPegLabel expression from the
        ast node and the lhs of the current rule.
        It uses the table `generator`.
    ]]
    return generator[node.tag](node, sym)
end

local function from_tag(tag)
    --[[
        To add the field 'tag' with the name or type
        of the node.
    ]]
    return lp.Cg(lp.P('') / tag, 'tag')
end

local function gen_skip()
    --[[
        Generate a `skip` rule if it is not defined yet
        by user.
    ]]
    if not M.grammar['skip'] then
        M.grammar['skip'] = lp.space^0
    end

    -- Add initial skip to initial symbol
    local init_sym = M.grammar[1]
    M.grammar[init_sym] = lp.V'skip' * M.grammar[init_sym]
end

local function is_lex(sym)
    return sym.type == 'lex'
end

local function is_syn(sym)
    return not is_lex(sym)
end

----------------------------------------------------------------------------
------------------- Generators for each AST tag ----------------------------
----------------------------------------------------------------------------
local skip_var = lp.V'skip'

generator['rule'] = function(node) 
    local sym_str = node[1][1]
    local sym = M.syms[sym_str]
    local rhs = node[2]
    local rhs_lpeg = to_lpeg(rhs, sym)

    -- If it's a lexical rule, capture all RHS.
    rhs_lpeg = is_lex(sym) and lp.C(rhs_lpeg) or rhs_lpeg

    M.grammar[sym_str] = lp.Ct( from_tag(sym_str) * rhs_lpeg )
end

generator['ord_exp'] = function(node, sym)
    local ret = to_lpeg(node[1], sym)
    for i = 2, #node do
        local exp = node[i]
        ret = ret + to_lpeg(exp, sym)
    end
    return ret
end

generator['seq_exp'] = function(node, sym)
    local ret = lp.P('')
    for _, exp in ipairs(node) do
        ret = ret * to_lpeg(exp, sym)
    end
    return ret
end

generator['rep_exp'] = function(node, sym)
    local exp_lpeg = to_lpeg(node[1], sym)
    return exp_lpeg^1
end

generator['literal'] = function(node, sym)
    local literal = node[1]
    local skip_var = is_syn(sym) and skip_var or lp.P('')
    if is_lex(sym) or not node.captured then
        return lp.P(literal) * skip_var
    else
        return lp.Ct( from_tag('token') * lp.C(literal) ) * skip_var
    end
end

generator['lex_sym'] = function(node, sym)
    -- TODO: Validate fragments are used only on lexical rules
    local lex_sym = node[1]
    local skip_var = is_syn(sym) and skip_var or lp.P('')
    return lp.V(lex_sym) * skip_var
end

generator['syn_sym'] = function(node, sym)
    -- TODO: Validate syntactic symbols are not used on lexical rules.
    local syn_sym = node[1]
    return lp.V(syn_sym)
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

M.gen = function (input)
    local ast = parser.match(input)
    M.grammar = {}
    get_syms(ast)

    for _, rule in ipairs(ast) do
        to_lpeg(rule)
    end
    gen_skip()

    return lp.P(M.grammar) * -1
end

return M