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

-- Grammar to be compiled with `lp.P`
local grammar = {}  -- stateful

----------------------------------------------------------------------------
----------------------------------------------------------------------------

local function get_syms (ast)
    --[[
        From AST, store in the module table the symbols with 
        info about their types and annotations.
    ]]
    local syms = {}
    for _, rule in ipairs(ast) do
        local sym = rule[1]
        local type = sym.tag == 'syn_sym' and 'syn' or 'lex'
        local is_fragment = rule.fragment and true or false     -- rule.fragment is "true" or nil
        local is_keyword = rule.keyword and true or false       -- rule.keyword is "true" or nil

        -- Save first symbol as first rule
        if #grammar == 0 then
            grammar[1] = sym[1]
        end

        -- Save rule
        syms[sym[1]] = {
            type = type,
            is_fragment = is_fragment,
            is_keyword = is_keyword
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
        Generate a `SKIP` rule if it is not defined yet
        by user.
    ]]
    if not grammar['SKIP'] then
        grammar['SKIP'] = lp.space^0
    end
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
local SKIP = lp.V'SKIP'

generator['rule'] = function(node) 
    local sym_str = node[1][1]
    local sym = M.syms[sym_str]
    local rhs = node[2]
    local rhs_lpeg = to_lpeg(rhs, sym)

    grammar[sym_str] = lp.Ct( from_tag(sym_str) * rhs_lpeg )
end

generator['literal'] = function(node, sym)
    local literal = node[1]
    local skip = is_syn(sym.type) and SKIP or lp.P('')
    if is_lex(sym.type) or not node.captured then
        return lp.P(literal) * skip
    else
        return lp.Ct( from_tag('token') * lp.C(literal) ) * skip
    end
end

generator['seq_exp'] = function(node, sym)
    local ret = lp.P('')
    for _, exp in ipairs(node) do
        ret = ret * to_lpeg(exp, sym)
    end
    return ret
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

M.gen = function (input)
    local ast = parser.match(input)
    grammar = {}
    get_syms(ast)

    for _, rule in ipairs(ast) do
        to_lpeg(rule)
    end

    gen_skip()
    return lp.P(grammar)
end

return M