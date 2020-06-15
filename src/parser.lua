local re = require"relabel"
local lp = require"lpeglabel"

local M = {}

-- TODO: Fragment annotation. Idea: Fragments are single quoted.
-- TODO: Keyword annotation. Idea: Keywords use backsticks.

local peg_grammar = [=[
    S       <- [%s%nl]* {| rule+ |} !.
    rule    <- {| {:tag: '' -> 'rule' :} {:keyword: '@' -> 'true' :}? name ARROW^ErrArrow exp^ErrExp (newlines / !. / %{ErrRuleEnd}) |}

    spaces      <- " "*
    newlines    <- %nl %s*

    LEX_ID  <- {| {:tag: '' -> 'lex_sym' :}    { [A-Z][A-Z0-9_]* } spaces |}
    SYN_ID  <- {| {:tag: '' -> 'syn_sym' :}    { [a-z][a-zA-Z0-9_]* } spaces |}
    name    <- LEX_ID / SYN_ID

    ARROW       <- '<-' spaces
    ORD_OP      <- '/' spaces
    STAR_OP     <- '*' spaces
    REP_OP      <- '+' spaces
    OPT_OP      <- '?' spaces
    AND_OP      <- '&' spaces
    NOT_OP      <- '!' spaces
    LPAR        <- '(' spaces
    RPAR        <- ')' spaces
    LQUOTES     <- '"'
    RQUOTES     <- '"' spaces
    LQUOTE      <- "'"
    RQUOTE      <- "'" spaces
    LBSTICK     <- "`"
    RBSTICK     <- "`" spaces
    LBRACKET    <- '{' spaces
    RBRACKET    <- '}' spaces
    COMMA       <- ',' spaces

    exp     <- ord 
    action  <- {| {:tag: '' -> 'action' :} LBRACKET exp^ErrExp COMMA^ErrComma {:action: ID^ErrID :} RBRACKET^ErrRBracket |}

    ord     <- (seq (ORD_OP seq^ErrChoice)*)   -> parse_ord
    seq     <- (unary (spaces unary)*)      -> parse_seq

    unary   <- star / rep / opt / and / not / atom
    star    <- {| {:tag: '' -> 'star_exp' :}   atom STAR_OP |}
    rep     <- {| {:tag: '' -> 'rep_exp' :}    atom REP_OP |}
    opt     <- {| {:tag: '' -> 'opt_exp' :}    atom OPT_OP |}
    and     <- {| {:tag: '' -> 'and_exp' :}    AND_OP atom^ErrAtom |}
    not     <- {| {:tag: '' -> 'not_exp' :}    NOT_OP atom^ErrAtom |}

    atom    <- token / class / name / LPAR exp RPAR^ErrRPar / action

    LITERAL     <- {| {:tag: '' -> 'literal' :}    LQUOTES  ('\"' / [^"])* -> parse_esc RQUOTES^ErrRQuotes |}
    FRAGMENT    <- {| {:tag: '' -> 'fragment' :}   LQUOTE   ("\'" / [^'])* -> parse_esc RQUOTE^ErrRQuote |}
    KEYWORD     <- {| {:tag: '' -> 'keyword' :}    LBSTICK  [^`]+ -> parse_esc RBSTICK^ErrRBStick|}

    ANY     <- {| {:tag: '' -> 'any' :}        { '.' } spaces |}
    EMPTY   <- {| {:tag: '' -> 'empty' :}      ('%e' 'mpty'? -> '%%e') spaces |}
    token   <- LITERAL / FRAGMENT / KEYWORD / ANY / EMPTY

    ID          <- [A-Za-z][A-Za-z0-9_]*
    predefined  <- '%' ID
    class       <- {| {:tag: '' -> 'class' :} { ('[' '^'? item (!']' item)* ']'^ErrRSquare) / predefined } spaces |}
    item        <- predefined / range / .
    range       <- . '-' [^]]^ErrRRange

]=]

M.errMsgs = {
    ErrArrow        = 'Arrow expected',
    ErrExp          = 'Valid expression expected',
    ErrRuleEnd      = 'Missing end of rule',
    ErrComma        = 'Missing comma',
    ErrID           = 'Valid identifier expected',
    ErrRBracket     = 'Closing bracket expected',
    ErrChoice       = 'Valid choice expected',
    ErrAtom         = 'Valid expression after predicate operator expected',
    ErrRPar         = 'Closing parentheses expected',
    ErrRQuotes      = 'Closing double quotes expected',
    ErrRQuote       = 'Closing single quotes expected',
    ErrRBStick      = 'Closing backstick expected',
    ErrRSquare      = 'Closing square bracket expected',
    ErrRRange       = 'Right bound of range expected',
}

local function parse_binary(tag)
    return function ( ... )
        local args = {...}
        if (#args == 1) then
            return args[1]
        else
            args.tag = tag
            return args
        end
    end
end

local function parse_esc(str)
    local ret = str:
                    gsub('\\a', '\a'):
                    gsub('\\b', '\b'):
                    gsub('\\f', '\f'):
                    gsub('\\n', '\n'):
                    gsub('\\r', '\r'):
                    gsub('\\t', '\t'):
                    gsub('\\v', '\v'):
                    gsub('\\\\', '\\'):
                    gsub('\\"', '"'):
                    gsub("\\'", "'")
    return ret
end

local peg_parser = re.compile(peg_grammar, {
    parse_ord = parse_binary"ord_exp",
    parse_seq = parse_binary"seq_exp",
    parse_esc = parse_esc,
})

function M.match(inp)
    local ast, errLabel, pos = peg_parser:match(inp)
    if not ast then
        local ln, col = re.calcline(inp, pos)
        local suffErrMsg = errLabel ~= "fail" and M.errMsgs[errLabel] or "fail"
        local errMsg = "Error at line " .. ln .. ", column " .. col .. ": " ..
            suffErrMsg
        error(errMsg)
    end
    return ast
end

function M.show_ast(ast, tabs)
    -- luacov: disable
    tabs = tabs or 0
    if (ast.tag) then
        print(string.rep("\t", tabs), ast.tag, "->")
        for _, node in ipairs(ast) do
            M.show_ast(node, tabs+2)
        end
    else
        print(string.rep("\t", tabs), ast)
    end
    -- luacov: enable
end

return M