local re = require"relabel"
local lp = require"lpeglabel"

local M = {}

-- TODO: Insert error labels for better error reporting
-- TODO: Fragment keyword

local peg_grammar = [=[
    S       <- [%s%nl]* {| rule+ |} !.
    rule    <- {| {:tag: '' -> 'rule' :} name ARROW exp (newlines / !.) |}

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
    LBRACKET    <- '{' spaces
    RBRACKET    <- '}' spaces
    COMMA       <- ',' spaces

    exp     <- ord / action
    action  <- {| {:tag: '' -> 'action' :} LBRACKET exp COMMA {:action: id :} RBRACKET |}

    ord     <- (seq (ORD_OP seq)*)      -> parse_ord
    seq     <- (unary (spaces unary)*)  -> parse_seq

    unary   <- star / rep / opt / and / not / atom
    star    <- {| {:tag: '' -> 'star_exp' :}   atom STAR_OP |}
    rep     <- {| {:tag: '' -> 'rep_exp' :}    atom REP_OP |}
    opt     <- {| {:tag: '' -> 'opt_exp' :}    atom OPT_OP |}
    and     <- {| {:tag: '' -> 'and_exp' :}    AND_OP atom |}
    not     <- {| {:tag: '' -> 'not_exp' :}    NOT_OP atom |}

    atom    <- token / class / name / LPAR exp RPAR

    LITERAL <- {| {:tag: '' -> 'literal' :}    (LQUOTES ('\"' / [^"])* -> parse_esc RQUOTES / LQUOTE ("\'" / [^'])* -> parse_esc RQUOTE ) |}
    ANY     <- {| {:tag: '' -> 'any' :}        { '.' } spaces |}
    EMPTY   <- {| {:tag: '' -> 'empty' :}      ('%e' 'mpty'? -> '%%e') spaces |}
    token   <- LITERAL / ANY / EMPTY

    id          <- [A-Za-z][A-Za-z0-9_]*
    predefined  <- '%' id
    class       <- {| {:tag: '' -> 'class' :} { ('[' '^'? item (!']' item)* ']') / predefined } spaces |}
    item        <- predefined / range / .
    range       <- . '-' [^]]

]=]

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
    return peg_parser:match(inp)
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