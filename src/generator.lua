local re = require"relabel"
local lp = require"lpeglabel"
local parser = require"caribay.parser"
local annotator = require"caribay.annotator"
local Symbol = require"Symbol"

lp.locale(lp) -- adds locale entries into 'lpeglabel' table
----------------------------------------------------------------------------
----------------------------------------------------------------------------

-- Module to export
local M = {}

function M.unique_token_prefix(literals_map)
    local literals_arr = {}     -- ordered array with the unique literals.
    local literals_patterns = {}  -- map of not predicates of array of tokens for which they are prefixes.

    for literal_str in pairs(literals_map) do 
        table.insert(literals_arr, literal_str) 
        literals_patterns[literal_str] = lp.P(literal_str)
    end
    table.sort(literals_arr)

    --[[
        For each token `literal_str`, if it's a prefix of a token `literal_str_1`,
        then add `literal_str_1` to the array of `literal_str`.
    ]]
    for idx, literal_str in ipairs(literals_arr) do
        for jdx = idx+1, #literals_arr do

            local literal_str_1 = literals_arr[jdx]

            if literal_str_1:find(literal_str, 1, true) then
                literals_patterns[literal_str] = literals_patterns[literal_str] - lp.P(literal_str_1)
            else
                break
            end
        end
    end

    return literals_patterns
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

-- Generator class
local Generator = {}

function Generator:new(actions, literals_map)

    -- Create new object
    local obj = {
        actions = actions or {},
        keywords = {},
        syms = {},
        grammar = {},
        labels = {},
        manual_labels = {},
        literals_patterns = M.unique_token_prefix(literals_map),
    }

    -- Inherit from `Generator`
    self.__index = self
    setmetatable(obj, self)
    return obj
end

-- generators for each kind of node
local generator = {}

----------------------------------------------------------------------------
------------------------- Auxiliar functions -------------------------------
----------------------------------------------------------------------------

local function parent_node_if_necessary(tag)
    return function ( captures )
        if (#captures == 1) then
            return captures[1]
        else
            captures.tag = tag
            return captures
        end
    end
end

function Generator:dont_match_keyword(subject, pos, ast_node)
    --[[
        Match ID if it is not a keyword
    ]]
    local identifier = ast_node[1]
    if self.keywords[identifier] then
        return false
    else
        return true, ast_node
    end
end

function Generator:unique_lex(literal_str, sym, is_only_child)
    --[[
        Ensures unique token prefix property for the token
        `literal_str`.
    ]]
    if is_only_child or sym:is_syn() then
        return self.literals_patterns[literal_str]
    else
        return lp.P(literal_str)
    end
end

local function is_lex_sym_str(sym_str)
    return re.match(sym_str, "[A-Z][A-Z0-9_]* !.")
end

----------------------------------------------------------------------------
--------------------------- Algorithm Unique -------------------------------
----------------------------------------------------------------------------
function Generator.create_lab_obj(seq, after_u, flw, sym)
    return {
        seq = seq,
        after_u = after_u,
        flw = flw,
        sym = sym,
    }
end

function Generator.unpack_lab_obj(lab_obj)
    return lab_obj.seq, lab_obj.after_u, lab_obj.flw, lab_obj.sym
end

function Generator:add_label(pattern, suf, lab_obj)
    --[[
        Receives a parsing expression p to annotate and its associated F OLLOW set f lw.
        Function addlab associates a label l to p and also builds a recovery expression
        for l based on flw
    ]]

    local _, _, flw, sym = Generator.unpack_lab_obj(lab_obj)

    -- If this is not the first label with this name,
    -- append correct number.
    local label = sym.sym_str .. '_' .. suf
    if self.labels[label] then
        local new_no = self.labels[label]+1
        self.labels[label] = new_no
        label = label .. new_no
    else
        self.labels[label] = 1
    end
    -- print('add label', label)
    return pattern + lp.T(label)
end

function Generator:lab_exp(ast_exp, lab_obj)
    --[[
        Annotates the right-hand side, a
        parsing expression, of each syntactical rule of the grammar.

        ast_exp:    an AST expression.

        lab_obj is an object with following fields:
        seq:        a boolean value indicating whether the current concatenation have already
                    matched at least one token.
        afterU:     a boolean value indicating whether the current right-hand side have already 
                    matched at least one unique lexical non-terminal.
        flw:        the F OLLOW set associated with ast_exp.
    ]]

    local seq, after_u, flw, sym = Generator.unpack_lab_obj(lab_obj)

    local annot = self.annot
    local first = annot:get_first(ast_exp)
    local tag = ast_exp.tag
    local suf

    --If it's a manually inserted label
    if tag == 'literal' or tag == 'keyword' or tag == 'lex_sym' or tag == 'syn_sym' then
        suf = ast_exp[1]
    else
        suf = tag
    end

    local pattern = self:to_lpeg(ast_exp, sym)

    if not first['%e'] and seq and after_u then
        return self:add_label(pattern, suf, lab_obj)
    elseif tag == 'seq_exp' then
        return self:lab_seq_exp(ast_exp, lab_obj)
    elseif tag == 'ord_exp' then
        return self:lab_ord_exp(ast_exp, lab_obj)
    elseif tag == 'star_exp' then
        return self:lab_star_exp(ast_exp[1], lab_obj)
    elseif tag == 'throw_exp' then
        local label = assert(ast_exp.label)
        self:insert_manual_label(label)
        return self:lab_exp(ast_exp[1], lab_obj) + lp.T(label)
    else
        return pattern
    end
end

function Generator:lab_seq_exp(seq_arr, lab_obj)
    --[[
        Annotates a sequencial expression.
    ]]

    local seq, after_u, flw, sym = Generator.unpack_lab_obj(lab_obj)

    local sub_exp1 = seq_arr[1]
    local annot = self.annot

    if #seq_arr == 1 then   -- If it is the only element in the sequence
        return self:lab_exp(sub_exp1, lab_obj)
    else
        local first1 = annot:get_first(sub_exp1)
        local seq_arry = {table.unpack(seq_arr, 2)}
        local flwx = annot:calck(seq_arry, flw, 'seq')

        local px = self:lab_exp(sub_exp1, Generator.create_lab_obj(seq, after_u, flwx, sym))
        local py = self:lab_seq_exp(
            seq_arry,
            Generator.create_lab_obj(
                seq or not first1['%e'], 
                after_u or annot:match_uni(sub_exp1), 
                flw,
                sym
            )
        )

        return px * py
    end
end

function Generator:lab_ord_exp(ord_arr, lab_obj)
    --[[
        Annotates an ordered choice.
    ]]
    local seq, after_u, flw, sym = Generator.unpack_lab_obj(lab_obj)

    local sub_exp1 = ord_arr[1]
    local annot = self.annot

    if #ord_arr == 1 then   -- If it is the only element in the sequence
        return self:lab_exp(sub_exp1, lab_obj)
    else
        local first1 = annot:get_first(sub_exp1)
        local ord_arry = {table.unpack(ord_arr, 2)}
        local disjoint = first1:disjoint(annot:calck(ord_arry, flw, 'ord'))

        local px = self:lab_exp(sub_exp1, Generator.create_lab_obj(false, disjoint and after_u, flw, sym))
        local py = self:lab_ord_exp(ord_arry, Generator.create_lab_obj(false, after_u, flw, sym))

        local ord_first = annot:get_ord_first(ord_arr)
        local pattern = px + py

        if seq and not ord_first['%e'] and after_u then
            return self:add_label(pattern, 'ord_exp', lab_obj)
        else
            return pattern
        end
    end
end

function Generator:lab_star_exp(exp, lab_obj)
    local seq, after_u, flw, sym = Generator.unpack_lab_obj(lab_obj)

    local annot = self.annot
    local first = annot:get_first(exp)
    local disjoint = first:disjoint(flw)
    return self:lab_exp(exp, Generator.create_lab_obj(false, disjoint and after_u, first:union(flw), sym))^0
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

function Generator:get_syms (ast)
    --[[
        From AST, store in the module table the symbols with 
        info about their types and annotations.
    ]]
    local syms = {
        SKIP = Symbol:new('SKIP', 'lex', true),
        ID_START = Symbol:new('ID_START', 'lex', true),
        ID_END = Symbol:new('ID_END', 'lex', true),
        ID = Symbol:new('ID', 'lex'),
    }

    for idx, rule in ipairs(ast) do
        local sym = rule[1]
        local sym_str = sym[1]
        local type = sym.tag == 'syn_sym' and 'syn' or 'lex'
        local is_fragment = rule.fragment and true or false     -- rule.fragment is "true" or nil
        local is_keyword = rule.keyword and true or false       -- rule.keyword is "true" or nil
        local is_skippable = rule.skippable and true or false

        -- Save first symbol as first rule
        if #self.grammar == 0 and not is_fragment then
            self.grammar[1] = sym[1]
            self.init = sym[1]
        end

        -- Save rule
        syms[sym_str] = syms[sym_str] or 
                        Symbol:new(sym_str, type, is_fragment, 
                                is_keyword, is_skippable, idx)
        
    end
    self.syms = syms
    return self.syms
end

function Generator:validate_syms(exp)
    --[[
        Validate every symbol used has its own rule
    ]]
    if exp.tag == 'lex_sym' or exp.tag == 'syn_sym' then
        return self.syms[exp[1]] or error("rule '" .. exp[1] .. "' undefined in given grammar")
    elseif exp.tag == 'rule' then
        return self:validate_syms(exp[2])
    else
        local ret = true
        for _, sub_exp in ipairs(exp) do
            ret = ret and self:validate_syms(sub_exp)
        end
        return ret
    end
end

function Generator:to_lpeg(node, sym, is_only_child)
    --[[
        Generates LPegLabel expression from the
        ast node and the lhs of the current rule.
        It uses the table `generator`.

        If `is_only_child` is true, this node is 
        considered as the only child of the parent node.
    ]]
    return generator[node.tag](self, node, sym, is_only_child)
end

local function from_tag(tag)
    --[[
        To add the field 'tag' with the name or type
        of the node.
    ]]
    return lp.Cg(lp.P('') / tag, 'tag') * lp.Cg(lp.Cp(), 'pos')
end

function Generator:gen_auxiliars()
    --[[
        Generate auxiliar rules if are not defined by the user yet.
    ]]

    -- Generate a 'SKIP' rule
    if not self.grammar['SKIP'] then
        if self.grammar['COMMENT'] then
            self.grammar['SKIP'] = (lp.space + lp.V'COMMENT' / 0)^0
        else
            self.grammar['SKIP'] = lp.space^0
        end
    end

    -- Add initial SKIP to initial symbol
    local init_sym = self.grammar[1]
    self.grammar[init_sym] = lp.V'SKIP' * self.grammar[init_sym]

    -- Generate an 'ID_START' rule
    if not self.grammar['ID_START'] then
        self.grammar['ID_START'] = re.compile('[a-zA-Z]')
    end

    -- Generate an 'ID_END' rule
    if not self.grammar['ID_END'] then
        self.grammar['ID_END'] = re.compile('[a-zA-Z0-9_]+')
    end

    -- Generate 'ID' rule
    local capture = lp.C( lp.V'ID_START' * lp.V'ID_END'^-1 )
    self.grammar['ID'] = lp.Cmt( lp.Ct( from_tag('ID') * capture ), function(...) 
        return self:dont_match_keyword(...) 
    end )

end

function Generator:insert_manual_label(label_str)
    self.manual_labels[#self.manual_labels+1] = label_str
end

local function throw_error(err, sym)
    error('Rule ' .. sym.sym_str .. ': ' .. err)
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
----------------------------------------------------------------------------

function Generator:lex_to_lpeg(lex, sym)
    local lex_sym = self.syms[lex]
    return add_SKIP(lp.V(lex), sym)
end

function Generator:syn_to_lpeg(syn, sym )
    local syn_sym = self.syms[syn]
    if sym:is_lex() then
        throw_error('Trying to use a syntactic element in a lexical rule', sym)
    else
        return lp.V(syn)
    end
end

function Generator:lit_to_lpeg(literal_str, sym, captured, is_only_child)
    local literal_lpeg = self:unique_lex(literal_str, sym, is_only_child)

    if sym:is_lex() or not captured then
        return add_SKIP(literal_lpeg, sym)
    else
        return add_SKIP(lp.Ct( from_tag('token') * lp.C(literal_lpeg) ), sym)
    end
end

function Generator:kw_to_lpeg(literal_str, sym, is_only_child )
    local literal_lpeg = self:unique_lex(literal_str, sym, is_only_child)

    -- Keep track of kwywords
    self.keywords[literal_str] = true

    local pattern = to_keyword(literal_lpeg)
    if sym:is_syn() then
        pattern = lp.Ct( from_tag('token') * lp.C(pattern) )
    end
    return add_SKIP(pattern, sym)
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

function Generator:get_labs_arr()
    local ret = {}
    for lab_str in pairs(self.labels) do
        ret[#ret+1] = lab_str
        if self.labels[lab_str] > 1 then
            for i=2,self.labels[lab_str] do
                ret[#ret+1] = lab_str .. '_' .. i
            end
        end
    end
    for _, lab_str in ipairs(self.manual_labels) do
        ret[#ret+1] = lab_str
    end
    table.sort(ret)
    return ret
end

----------------------------------------------------------------------------
------------------- Generators for each AST tag ----------------------------
----------------------------------------------------------------------------

generator['rule'] = function(self, node) 
    local sym_str = node[1][1]  -- Name of the symbol
    local sym = self.syms[sym_str] -- Symbol 'object'
    local rhs = node[2]
    local is_only_child = rhs.tag == 'literal' or rhs.tag == 'keyword'
    
    local rhs_lpeg
    
    if sym:is_lex() then
        rhs_lpeg = self:to_lpeg(rhs, sym, is_only_child)
    else
        -- Annotate RHS if it's a syntactic rule
        local annot = self.annot
        rhs_lpeg = self:lab_exp(rhs, Generator.create_lab_obj(false, false, annot.follow[sym_str], sym))
    end

    if sym.is_keyword then
        rhs_lpeg = to_keyword(rhs_lpeg)
    end

    if sym.is_fragment then
        self.grammar[sym_str] = rhs_lpeg
    else
        -- If it's a lexical rule, capture all RHS.
        rhs_lpeg = sym:is_lex() and lp.C(rhs_lpeg / 0) or rhs_lpeg

        -- If it's skippable, don't capture if it only has one child
        if sym.is_skippable then
            self.grammar[sym_str] = lp.Ct( lp.Cg(lp.Cp(), 'pos') * rhs_lpeg ) / parent_node_if_necessary(sym_str)
        else
            self.grammar[sym_str] = lp.Ct( from_tag(sym_str) * rhs_lpeg )
        end
    end
end

generator['lex_sym'] = function(self, node, sym)
    return self:lex_to_lpeg(node[1], sym)
end

generator['syn_sym'] = function(self, node, sym)
    return self:syn_to_lpeg(node[1], sym)
end

generator['ord_exp'] = function(self, node, sym)
    local ret = self:to_lpeg(node[1], sym)
    for i = 2, #node do
        local exp = node[i]
        ret = ret + self:to_lpeg(exp, sym)
    end
    return ret
end

generator['seq_exp'] = function(self, node, sym)
    local ret = lp.P('')
    for _, exp in ipairs(node) do
        ret = ret * self:to_lpeg(exp, sym)
    end
    return ret
end

generator['throw_exp'] = function(self, node, sym)
    if sym:is_lex() then
        throw_error('Error labels inside lexical rules are forbidden', sym)
    else
        local label = assert(node.label)
        self:insert_manual_label(label)
        return self:to_lpeg(node[1], sym) + lp.T(label)
    end
end

generator['back_exp'] = function(self, node)
    return lp.Cb(node[1])
end

generator['star_exp'] = function(self, node, sym)
    local exp_lpeg = self:to_lpeg(node[1], sym)
    return exp_lpeg^0
end

generator['rep_exp'] = function(self, node, sym)
    local exp_lpeg = self:to_lpeg(node[1], sym)
    return exp_lpeg^1
end

generator['opt_exp'] = function(self, node, sym)
    local exp_lpeg = self:to_lpeg(node[1], sym)
    return exp_lpeg^-1
end

generator['not_exp'] = function(self, node, sym)
    local exp_lpeg = self:to_lpeg(node[1], sym)
    return -exp_lpeg
end

generator['and_exp'] = function(self, node, sym)
    local exp_lpeg = self:to_lpeg(node[1], sym)
    return #exp_lpeg
end

generator['literal'] = function(self, node, sym, is_only_child)
    local literal_str = node[1]
    return self:lit_to_lpeg(literal_str, sym, node.captured, is_only_child)
end

generator['keyword'] = function(self, node, sym, is_only_child)
    local literal_str = node[1]
    return self:kw_to_lpeg(literal_str, sym, is_only_child)
end

generator['class'] = function(self, node, sym)
    local chr_class = node[1]
    local lpeg_class = re.compile(chr_class)
    return capt_if_syn(lpeg_class, sym)
end

generator['any'] = function(self, node, sym)
    local lpeg_class = lp.P(1)
    return capt_if_syn(lpeg_class, sym)
end

generator['empty'] = function(self, node, sym)
    return lp.P('')
end

generator['action'] = function(self, node, sym)
    local action_name = node.action
    local action = self.actions[action_name]
    local exp_lpeg = self:to_lpeg(node[1], sym)
    return lp.Cmt(exp_lpeg, action)
end

generator['group'] = function(self, node, sym)
    local group_name = node.group
    local exp_lpeg = self:to_lpeg(node[1], sym)
    return lp.Cg(exp_lpeg, group_name)
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------

M.gen = function (input, actions)
    local generator, annot = M.annotate(input, actions)

    for _, rule in ipairs(annot.ast) do
        generator:to_lpeg(rule)
    end
    generator:gen_auxiliars()

    local parser = lp.P(generator.grammar) * (lp.P(-1) + lp.T('EOF') )
    local labs_arr = generator:get_labs_arr()

    return parser, labs_arr
end

M.annotate = function(input, actions)
    local ast, literals = parser.match(input)
    local generator = Generator:new(actions, literals)
    local syms = generator:get_syms(ast)
    generator:validate_syms(ast)

    local annot = annotator.annotate(ast, syms, generator.init)
    generator.annot = annot
    return generator, annot
end

return M