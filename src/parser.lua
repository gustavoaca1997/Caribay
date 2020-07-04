local re = require"relabel"
local lp = require"lpeglabel"

local M = {}
local literals = {} -- Literals and keywords found on the grammar

local peg_grammar = [=[
    S       <- [%s%nl]* {| rule+ |} !.
    rule    <- {| {:tag: '' -> 'rule' :} frgmnt? kywrd? name arrow^ErrArrow exp^ErrExp (newlines / !. )^ErrRuleEnd |}
    
    frgmnt       <- {:fragment: frgmnt_annot -> 'true' :}
    frgmnt_annot <- "fragment" spaces (&(kywrd_annot / name))^ErrAnnot

    kywrd        <- {:keyword: kywrd_annot -> 'true' :}
    kywrd_annot  <- "keyword" spaces (&LEX_ID)^ErrLexId

    SPACE       <- " "
    spaces      <- SPACE+
    skip        <- SPACE*
    newlines    <- %nl %s*

    LEX_ID  <- {| {:tag: '' -> 'lex_sym' :}    { [A-Z][A-Z0-9_]* } skip |}
    SYN_ID  <- {| {:tag: '' -> 'syn_sym' :}    { [a-z][a-zA-Z0-9_]* } skip |}
    name    <- LEX_ID / SYN_ID

    arrow       <- ARROW / ARROW_SKP 
    ARROW       <- '<-' skip
    ARROW_SKP   <- {:skippable: '<~' -> 'true' :} skip

    ORD_OP      <- '/' %s*
    BACK_OP     <- '^' skip
    STAR_OP     <- '*' skip
    REP_OP      <- '+' skip
    OPT_OP      <- '?' skip
    AND_OP      <- '&' skip
    NOT_OP      <- '!' skip
    LPAR        <- '(' skip
    RPAR        <- ')' skip
    LQUOTES     <- '"'
    RQUOTES     <- '"' skip
    LQUOTE      <- "'"
    RQUOTE      <- "'" skip
    LBSTICK     <- "`"
    RBSTICK     <- "`" skip
    LBRACKET    <- '{' skip
    RBRACKET    <- '}' skip
    COMMA       <- ',' skip
    COLON       <- ':' skip

    exp     <- ord 
    ord     <- (seq (ORD_OP seq^ErrChoice)*)   -> parse_ord
    seq     <- (unary (skip unary)*)      -> parse_seq

    unary   <- back / star / rep / opt / and / not / atom
    back    <- {| {:tag: '' -> 'back_exp' :}   BACK_OP {ID}^ErrID skip |}
    star    <- {| {:tag: '' -> 'star_exp' :}   atom STAR_OP |}
    rep     <- {| {:tag: '' -> 'rep_exp' :}    atom REP_OP |}
    opt     <- {| {:tag: '' -> 'opt_exp' :}    atom OPT_OP |}
    and     <- {| {:tag: '' -> 'and_exp' :}    AND_OP atom^ErrAtom |}
    not     <- {| {:tag: '' -> 'not_exp' :}    NOT_OP atom^ErrAtom |}

    atom    <- token / class / name / LPAR exp RPAR^ErrRPar / action / group

    action  <- {| {:tag: '' -> 'action' :} LBRACKET exp^ErrExp COMMA {:action: ID^ErrID :} skip RBRACKET^ErrRBracket |}
    group   <- {| {:tag: '' -> 'group' :}  LBRACKET exp^ErrExp COLON {:group: ID^ErrID :} skip RBRACKET^ErrRBracket |}

    escaped <-  ('\' ('a' / 'b' / 'f' / 'n' / 'r' / 't' / 'v' / '\' / '"' / "'" / 'n')) -> parse_esc

    literal1    <- {| (escaped / {[^"]})* |} -> concat_chars
    literal2    <- {| (escaped / {[^']})* |} -> concat_chars
    literal3    <- {| (escaped / {[^`]})+ |} -> concat_chars

    CAPTURED    <- {| {:tag: '' -> 'literal' :} {:captured: '' -> 'true' :} LQUOTES  literal1 RQUOTES^ErrRQuotes |}
    LITERAL     <- {| {:tag: '' -> 'literal' :}  LQUOTE   literal2 RQUOTE^ErrRQuote |}
    KEYWORD     <- {| {:tag: '' -> 'keyword' :}  LBSTICK  literal3 RBSTICK^ErrRBStick|}

    ANY     <- {| {:tag: '' -> 'any' :}        { '.' } skip |}
    EMPTY   <- {| {:tag: '' -> 'empty' :}      ('%e' 'mpty'? -> '%%e') skip |}
    token   <- LITERAL / CAPTURED / KEYWORD / ANY / EMPTY

    ID          <- [A-Za-z][A-Za-z0-9_]*
    predefined  <- '%' ID
    class       <- {| {:tag: '' -> 'class' :} { ('[' '^'? item (!']' item)* ']'^ErrRSquare) / predefined } skip |}
    item        <- predefined / range / .
    range       <- . '-' [^]]^ErrRRange

]=]

M.errMsgs = {
    ErrArrow        = 'Arrow expected',
    ErrLexId        = 'Lexical identifier expected',
    ErrName         = 'Symbol identifier expected',
    ErrAnnot        = 'Annotated symbol expected',
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

local escape_map = {
    ['\\a'] = '\a',
    ['\\b'] = '\b',
    ['\\f'] = '\f',
    ['\\r'] = '\r',
    ['\\n'] = '\n',
    ['\\t'] = '\t',
    ['\\v'] = '\v',
    ['\\\\'] = '\\',
    ['\\"'] = '"',
    ["\\'"] = "'",
}

local function parse_esc(str)
   return escape_map[str]
end

local function concat_chars(parts)
    local literal_str = table.concat(parts)
    literals[literal_str] = true
    return literal_str
end

local peg_parser = re.compile(peg_grammar, {
    parse_ord = parse_binary"ord_exp",
    parse_seq = parse_binary"seq_exp",
    parse_esc = parse_esc,
    concat_chars = concat_chars,
})

function M.match(inp)
    literals = {}
    local ast, errLabel, pos = peg_parser:match(inp)
    if not ast then
        local ln, col = re.calcline(inp, pos)
        local suffErrMsg = errLabel ~= "fail" and M.errMsgs[errLabel] or "fail"
        local errMsg = "Error at line " .. ln .. ", column " .. col .. ": " ..
            suffErrMsg
        error(errMsg)
    end
    return ast, literals
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