local re = require"relabel"

local M = {}

-- TODO: Insert error labels for better error reporting

local peg_grammar = [=[
    S       <- {| rule+ !. |}

    spaces  <- %s*

    LEX_ID  <- {| {:tag: '' -> 'lex_sym' :}    { [A-Z][A-Z_]* } spaces |}
    SYN_ID  <- {| {:tag: '' -> 'syn_sym' :}    { [a-z][a-zA-Z0-9_]* } spaces |}
    name    <- LEX_ID / SYN_ID

    ARROW   <- '<-' spaces
    ORD_OP  <- '/' spaces
    STAR_OP <- '*' spaces
    REP_OP  <- '+' spaces
    OPT_OP  <- '?' spaces
    AND_OP  <- '&'
    NOT_OP  <- '!'
    LPAR    <- '(' spaces
    RPAR    <- ')' spaces
    LQUOTES <- '"'
    RQUOTES <- '"' spaces

    rule    <- {| {:tag: '' -> 'rule' :} name ARROW ord |}

    ord     <- {| {:tag: '' -> 'ord_exp' :}    seq (ORD_OP seq)* |}
    seq     <- {| {:tag: '' -> 'seq_exp' :}    unary (spaces unary)* |}

    unary   <- star / rep / opt / and / not / atom
    star    <- {| {:tag: '' -> 'star_exp' :}   atom STAR_OP |}
    rep     <- {| {:tag: '' -> 'rep_exp' :}    atom REP_OP |}
    opt     <- {| {:tag: '' -> 'opt_exp' :}    atom OPT_OP |}
    and     <- {| {:tag: '' -> 'and_exp' :}    AND_OP atom |}
    not     <- {| {:tag: '' -> 'not_exp' :}    NOT_OP atom |}

    atom    <- class / name / LPAR ord RPAR / token

    LITERAL <- {| {:tag: '' -> 'literal' :}    LQUOTES { [^"]* } RQUOTES |}
    ANY     <- {| {:tag: '' -> 'any' :}        { '.' } spaces |}
    EMPTY   <- {| {:tag: '' -> 'empty' :}      { '%e' / '%empty' } spaces |}
    token   <- LITERAL / ANY / EMPTY

    class   <- {| {:tag: '' -> 'class' :} { '[' '^'? item (!']' item)* ']' } |}
    item    <- defined / range / .
    defined <- '%' [A-Za-z][A-Za-z0-9_]*
    range   <- . '-' [^]]

]=]

local peg_parser = re.compile(peg_grammar)

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