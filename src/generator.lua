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

-- Symbol class
local Symbol = {}

function Symbol:is_lex()
    return self.type == 'lex'
end

function Symbol:is_syn()
    return self.type == 'syn'
end

function Symbol:new(obj)
    obj = obj or {}
    self.__index = self
    setmetatable(obj, self)
    return obj
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

local function get_syms (ast)
    --[[
        From AST, store in the module table the symbols with 
        info about their types and annotations.
    ]]
    local syms = {
        SKIP = Symbol:new{
            type = 'syn',
            is_fragment = true,
            is_keyword = false,
        },
        ID_START = Symbol:new{
            type = 'lex',
            is_fragment = true,
            is_keyword = false,
        },
        ID_END = Symbol:new{
            type = 'lex',
            is_fragment = true,
            is_keyword = false,
        },
        ID = Symbol:new{
            type = 'lex',
            is_fragment = false,
            is_keyword = false,
        }
    }

    for idx, rule in ipairs(ast) do
        local sym = rule[1]
        local type = sym.tag == 'syn_sym' and 'syn' or 'lex'
        local is_fragment = rule.fragment and true or false     -- rule.fragment is "true" or nil
        local is_keyword = rule.keyword and true or false       -- rule.keyword is "true" or nil

        -- Save first symbol as first rule
        if #M.grammar == 0 and not is_fragment then
            M.grammar[1] = sym[1]
        end

        -- Save rule
        syms[sym[1]] = syms[sym[1]] or Symbol:new{ -- `or` mainly for keeping auxiliar entries intact
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
    return lp.Cg(lp.P('') / tag, 'tag') * lp.Cg(lp.Cp(), 'pos')
end

local function gen_auxiliars()
    --[[
        Generate auxiliar rules if are not defined by the user yet.
    ]]

    -- Generate a 'SKIP' rule
    if not M.grammar['SKIP'] then
        M.grammar['SKIP'] = lp.space^0
    end

    -- Add initial SKIP to initial symbol
    local init_sym = M.grammar[1]
    M.grammar[init_sym] = lp.V'SKIP' * M.grammar[init_sym]

    -- Generate an 'ID_START' rule
    if not M.grammar['ID_START'] then
        M.grammar['ID_START'] = re.compile('[a-zA-Z]+')
    end

    -- Generate an 'ID_END' rule
    if not M.grammar['ID_END'] then
        M.grammar['ID_END'] = re.compile('[a-zA-Z0-9_]+')
    end

    -- Generate 'ID' rule
    local capture = lp.C( lp.V'ID_START' * lp.V'ID_END'^-1 )
    M.grammar['ID'] = lp.Ct( from_tag('ID') * capture )
end

local function throw_error(err, sym)
    error('Rule ' .. sym.rule_no .. ': ' .. err)
end

local function to_keyword(pattern)
    return pattern * (-lp.V'ID_END')
end

local SKIP_var = lp.V'SKIP'

local function add_SKIP(pattern, sym)
    local SKIP_var = sym:is_syn() and SKIP_var or lp.P('')
    return pattern * SKIP_var
end

local function capt_if_syn(pattern, sym)
    return sym:is_syn() and lp.C(pattern) or pattern
end

----------------------------------------------------------------------------
------------------- Generators for each AST tag ----------------------------
----------------------------------------------------------------------------

generator['rule'] = function(node) 
    local sym_str = node[1][1]  -- Name of the symbol
    local sym = M.syms[sym_str] -- Symbol 'object'
    local rhs = node[2]
    local rhs_lpeg = to_lpeg(rhs, sym)

    if sym.is_keyword then
        rhs_lpeg = to_keyword(rhs_lpeg)
    end

    if sym.is_fragment then
        M.grammar[sym_str] = rhs_lpeg
    else
        -- If it's a lexical rule, capture all RHS.
        rhs_lpeg = sym:is_lex() and lp.C(rhs_lpeg) or rhs_lpeg
        M.grammar[sym_str] = lp.Ct( from_tag(sym_str) * rhs_lpeg )
    end
end

generator['lex_sym'] = function(node, sym)
    local lex = node[1]
    local lex_sym = M.syms[lex]

    if sym:is_lex() and not lex_sym.is_fragment then
        throw_error('Trying to use a not fragment lexical element in a lexical rule', sym)
    else
        return add_SKIP(lp.V(lex), sym)
    end

end

generator['syn_sym'] = function(node, sym)
    local syn = node[1]
    local syn_sym = M.syms[syn]
    if sym:is_lex() then
        throw_error('Trying to use a syntactic element in a lexical rule', sym)
    else
        return lp.V(syn)
    end
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

generator['star_exp'] = function(node, sym)
    local exp_lpeg = to_lpeg(node[1], sym)
    return exp_lpeg^0
end

generator['rep_exp'] = function(node, sym)
    local exp_lpeg = to_lpeg(node[1], sym)
    return exp_lpeg^1
end

generator['opt_exp'] = function(node, sym)
    local exp_lpeg = to_lpeg(node[1], sym)
    return exp_lpeg^-1
end

generator['not_exp'] = function(node, sym)
    local exp_lpeg = to_lpeg(node[1], sym)
    return -exp_lpeg
end

generator['and_exp'] = function(node, sym)
    local exp_lpeg = to_lpeg(node[1], sym)
    return #exp_lpeg
end

generator['literal'] = function(node, sym)
    local literal = node[1]

    if sym:is_lex() or not node.captured then
        return add_SKIP(lp.P(literal), sym)
    else
        return add_SKIP(lp.Ct( from_tag('token') * lp.C(literal) ), sym)
    end
end

generator['keyword'] = function(node, sym)
    local literal = node[1]
    local pattern = to_keyword(lp.P(literal))
    if sym:is_syn() then
        pattern = lp.Ct( from_tag('token') * lp.C(pattern) )
    end
    return add_SKIP(pattern, sym)
end

generator['class'] = function(node, sym)
    local chr_class = node[1]
    local lpeg_class = re.compile(chr_class)
    return capt_if_syn(lpeg_class, sym)
end

generator['any'] = function(node, sym)
    local lpeg_class = lp.P(1)
    return capt_if_syn(lpeg_class, sym)
end

generator['empty'] = function(node, sym)
    return lp.P('')
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
    gen_auxiliars()

    return lp.P(M.grammar) * -1
end

return M