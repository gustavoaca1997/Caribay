local function create_first(obj)
    local ret = {
        ID = {
            ID = true 
        },
        ID_END = {
            ID_END = true 
        },
        ID_START = {
            ID_START = true 
        },
        SKIP = {
            SKIP = true,
        }
    }
    for k, v in pairs(obj) do
        ret[k] = v
    end
    return ret
end

context("Annotator", function()
    setup(function()
        parser = require"caribay.parser"
        generator = require"caribay.generator"
        annotator = require"caribay.generator"

        re = require"relabel"
        lfs = require"lfs"
    end)

    -- TODO: Alse test FOLLOW and then the annotated AST.
    context("computes FIRST set", function()
        context("for a parser with", function()
            context("a rule with", function()
                test("a repetition of character class", function()
                    local src1 = 'ALPHA_NUM <- [0-9a-zA-Z]+'
                    local _, annot1 = generator.annotate(src1)
                    local expected_first1 = create_first{
                        ALPHA_NUM = { ALPHA_NUM = true }
                    }

                    local src2 = 'alpha_num <- [0-9a-zA-Z]+'
                    local _, annot2 = generator.annotate(src2)
                    local expected_first2 = create_first{
                        alpha_num = { ['[0-9a-zA-Z]'] = true }
                    }

                    assert.are.same(expected_first1, annot1.first)
                    assert.are.same(expected_first2, annot2.first)
                end)

                test("a captured literal", function()
                    local src = 's <- "a"'
                    local _, annot = generator.annotate(src)
                    local expected_first = create_first{
                        s = { ["'a'"] = true }
                    }
                    assert.are.same(expected_first, annot.first)
                end)

                test("a not captured literal", function()
                    local src = "s <- 'a'"
                    local _, annot = generator.annotate(src)
                    local expected_first = create_first{
                        s = { ["'a'"] = true }
                    }
                    assert.are.same(expected_first, annot.first)
                end)

                test("a captured literal between two not captured literals", function()
                    local src = [[
                        s <- '->' "a" '<-'
                    ]]
                    local _, annot = generator.annotate(src)
                    local expected_first = create_first{
                        s = { ["'->'"] = true }
                    }
                    assert.are.same(expected_first, annot.first)
                end)

                test("a backslash", function()
                    local src = [[
                        s <- "\\t" "a"
                    ]]
                    local _, annot = generator.annotate(src)
                    local expected_first = create_first{
                        s = {
                            [ [['\t']] ] = true
                        }
                    }
                    assert.are.same(expected_first, annot.first)
                end)

                test("an ordered choice of literals", function()
                    local src = [[
                        s <- "a" / "b" / "c"
                    ]]
                    local _, annot = generator.annotate(src)
                    local expected_first = create_first{
                        s = {
                            ["'a'"] = true,
                            ["'b'"] = true,
                            ["'c'"] = true,
                        }
                    }
                    assert.are.same(expected_first, annot.first)
                end)

                test("empty token", function()
                    local src = [[
                        s <- A
                        A <- 'a' (A / %e) 'b'
                    ]]
                    local _, annot = generator.annotate(src)
                    local expected_first = create_first{
                        s = {
                            ["'a'"] = true,
                        },
                        A = {
                            ["'a'"] = true,
                        }
                    }
                end)

                test("sequences as ordered choices", function()
                    local src = [[
                        s <- "a" '!' / '{' "b" '}' / '&' "c"
                    ]]
                    local _, annot = generator.annotate(src)
                    local expected_first = create_first{
                        s = {
                            ["'a'"] = true,
                            ["'{'"] = true,
                            ["'&'"] = true,
                        }
                    }
                end)
            end)

            test("three syntactic rules", function()
                local src = [[
                    s <- between_brackets / between_parentheses
    
                    between_brackets    <- '{' "b" '}'
                    between_parentheses <- '(' "p" ')' 
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    s = {
                        ["'{'"] = true,
                        ["'('"] = true,
                    },
                    between_brackets = {
                        ["'{'"] = true,
                    },
                    between_parentheses = {
                        ["'('"] = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("two trivial lexical rules and one initial syntactic rule", function()
                local src = [[
                    full_name <- FIRST LAST
                    FIRST <- 'Gustavo'
                    LAST <- 'Castellanos'
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    full_name = { FIRST = true },
                    FIRST = { FIRST = true, },
                    LAST = { LAST = true, }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("and predicate", function()
                -- Context-sensitive language {a^n b^n c^n : n >= 1}
                local src = [[
                    s <- &(A 'c') 'a'+ B
                    A <- 'a' A? 'b'
                    B <- 'b' B? 'c'
                ]]

                local expected_first = create_first{
                    s = {
                        ["'a'"] = true,
                    },
                    A = {
                        ["'a'"] = true,
                    },
                    B = {
                        ["'b'"] = true,
                    },
                }
            end)

            test("some fragments", function()
                local src = [[
                    list <- number+
                    number <- INT / FLOAT
                    INT <- %d+ !'.'
                    FLOAT <- %d+ '.' %d+
                ]]

                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    FLOAT = { FLOAT = true },
                    INT = { INT = true },
                    number = {
                        INT = true,
                        FLOAT = true,
                    },
                    list = {
                        INT = true,
                        FLOAT = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("syntactic repetition of bits", function()
                local src = [[
                    rand_bits <- BIT+
                    BIT <- '0' / '1'
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    BIT = { BIT = true },
                    rand_bits = { BIT = true }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("default ID rule and a keyword", function()
                local src = [[
                    s <- (print / assign)+
                    assign <- ID '=' INT
                    INT <- %d+
                    print <- `print` ID
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    INT = { INT = true },
                    print = {
                        ["`print`"] = true,
                    },
                    assign = { ID = true },
                    s = {
                        ["`print`"] = true,
                        ID = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("keyword rules and its own SKIP rule", function()
                local src = [[
                    s <- (init / idx)+
                    init <- VECTOR ID
                    idx <- ID '.' INT
    
                    keyword VECTOR <- 'vector' [1-9]
                    INT <- %d+
    
                    SKIP <- (' ' / '\n' / ';')*
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    INT = { INT = true },
                    VECTOR = { VECTOR = true },
                    idx = { ID = true },
                    init = { VECTOR = true },
                    s = {
                        VECTOR = true,
                        ID = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("user defined `COMMENT`", function()
                local src = [[
                    s <- NUMBER (',' NUMBER)*
                    COMMENT <- '--' [^%nl]*
                    NUMBER <- %d+
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    NUMBER = { NUMBER = true },
                    COMMENT = { COMMENT = true },
                    s = { NUMBER = true },
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("a prefix empty expression I", function()
                local src = [[
                    s <- %e "a"
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    s = {
                        ["'a'"] = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("a prefix empty expression II", function()
                local src = [[
                    s <- '' "a"
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    s = {
                        ["'a'"] = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("a prefix star expression I", function()
                local src = [[
                    s <- "="*
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    s = {
                        ["'='"] = true,
                        ["%e"] = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("a prefix star expression II", function()
                local src = [[
                    s <- (";" / dots)* ":"
                    dots <- "."+
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    dots = {
                        ["'.'"] = true,
                    },
                    s = {
                        ["';'"] = true,
                        ["'.'"] = true,
                        ["':'"] = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("a prefix option expression", function()
                local src = [[
                    s <- ((";" / dots) ":")? "!"
                    dots <- "."*
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    dots = {
                        ["'.'"] = true,
                        ["%e"] = true,
                    },
                    s = {
                        ["'!'"] = true,
                        ["';'"] = true,
                        ["'.'"] = true,
                        ["':'"] = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("a named group and a semantic acton", function()
                local src = [[
                    long_str    <-  { open_str : init_eq } '\n'? (!close_eq .)* close_str
                    close_eq    <-  { close_str ^init_eq , check_eq }
                    equals      <-  '='*
                    open_str    <-  '[' equals '['
                    close_str   <-  ']' equals ']'
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    open_str = {
                        ["'['"] = true,
                    },
                    close_str = {
                        ["']'"] = true,
                    },
                    equals = {
                        ["'='"] = true,
                        ["%e"] = true,
                    },
                    close_eq = {
                        ["']'"] = true,
                    },
                    long_str = {
                        ["'['"] = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("a syntactic named group", function()
                local src = [[
                    s <- { "="* : equals} ^equals
                ]]
                local _, annot = generator.annotate(src)
                local expected_first = create_first{
                    s = {
                        ["%e"] = true,
                        ["'='"] = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("from JSON grammar", function()
                local f = assert(io.open("./test/expected/json/grammar.peg", "r"))
                local src = f:read("a")
                local _, annot = generator.annotate(src)
                f:close()
        
                local expected_first = create_first{
                    NUMBER = { NUMBER = true },
                    STRING = { STRING = true },
                    BOOLEAN = { BOOLEAN = true },
                    pair = { STRING = true },
                    object = {
                        ["'{'"] = true,
                    },
                    array = {
                        ["'['"] = true,
                    },
                    value = {
                        ["'{'"] = true,
                        ["'['"] = true,
                        BOOLEAN = true,
                        STRING = true,
                        NUMBER = true,
                        ["`null`"] = true,
                    },
                    json = {
                        ["'{'"] = true,
                        ["'['"] = true,
                        BOOLEAN = true,
                        STRING = true,
                        NUMBER = true,
                        ["`null`"] = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)

            test("from Lua grammar", function()
                local f = assert(io.open("./test/expected/lua/grammar.peg", "r"))
                local src = f:read("a")
                local _, annot = generator.annotate(src)
                f:close()
        
                local expected_first = create_first{
                    ESC = { ESC = true },
                    STRING = { STRING = true },
                    EQUALS = { EQUALS = true },
                    OPEN_STR = { OPEN_STR = true },
                    CLOSE_STR = {CLOSE_STR = true },
                    CLOSE_EQ = {CLOSE_EQ = true },
                    LONG_STR = { LONG_STR = true },
                    NUMBER = { NUMBER = true },
                    COMMENT = { COMMENT = true },
                    SP_COMMENT = { SP_COMMENT = true };

                    fieldsep = {
                        ["','"] = true,
                        ["';'"] = true,
                    },
                    field = {
                        ["'['"] = true,
                        ID = true,
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    fieldlist = {
                        ["'['"] = true,
                        ID = true,
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    tableconstructor = { ["'{'"] = true },
                    parlist = {
                        ID = true,
                        ["'...'"] = true,
                    },
                    funcbody = { ["'('"] = true },
                    ["function"] = { ["`function`"] = true },
                    args = {
                        ["'('"] = true,
                        ["'{'"] = true,
                        STRING = true,
                    },
                    functioncall = {
                        ID = true,
                        ["'('"] = true,
                    },
                    prefiexp = {
                        ID = true,
                        ["'('"] = true,
                    },
                    prefiatom = {
                        ID = true,
                        ["'('"] = true,
                    },
                    unary_op = { 
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                    },
                    factor_op = {
                        ["'*'"] = true,
                        ["'/'"] = true,
                        ["'%'"] = true,
                    },
                    term_op = {
                        ["'+'"] = true,
                        ["'-'"] = true,
                    },
                    comp_op = {
                        ["'<'"] = true,
                        ["'>'"] = true,
                        ["'<='"] = true,
                        ["'>='"] = true,
                        ["'~='"] = true,
                        ["'=='"] = true,
                    },
                    atom_exp = {
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    unary = {
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    factor = {
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    term = {
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    arit = {
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    conc = {
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    comp = {
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    conj = {
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    exp = {
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    explist = {
                        ["`not`"] = true,
                        ["'#'"] = true,
                        ["'-'"] = true,
                        ["`nil`"] = true,
                        ["`false`"] = true,
                        ["`true`"] = true,
                        NUMBER = true,
                        STRING = true,
                        ["`function`"] = true,
                        ["'...'"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["'{'"] = true,
                    },
                    namelist = { ID = true },
                    sufiexp = {
                        ["'.'"] = true,
                        ["'['"] = true,
                    },
                    dot_exp = { ["'.'"] = true },
                    key_exp = { ["'['"] = true },
                    var = {
                        ID = true,
                        ["'('"] = true,
                    },
                    varlist = {
                        ID = true,
                        ["'('"] = true,
                    },
                    funcname = { ID = true },
                    laststat = {
                        ["`return`"] = true,
                        ["`break`"] = true,
                    },
                    stat = {
                        ["`do`"] = true,
                        ["`while`"] = true,
                        ["`repeat`"] = true,
                        ["`if`"] = true,
                        ["`for`"] = true,
                        ["`function`"] = true,
                        ["`local`"] = true,
                        ID = true,
                        ["'('"] = true,
                    },
                    block = {
                        ["`do`"] = true,
                        ["`while`"] = true,
                        ["`repeat`"] = true,
                        ["`if`"] = true,
                        ["`for`"] = true,
                        ["`function`"] = true,
                        ["`local`"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["`return`"] = true,
                        ["`break`"] = true,
                        ["%e"] = true,
                    },
                    chunk = {
                        ["`do`"] = true,
                        ["`while`"] = true,
                        ["`repeat`"] = true,
                        ["`if`"] = true,
                        ["`for`"] = true,
                        ["`function`"] = true,
                        ["`local`"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["`return`"] = true,
                        ["`break`"] = true,
                        ["%e"] = true,
                    },
                    program = {
                        SP_COMMENT = true,
                        ["`do`"] = true,
                        ["`while`"] = true,
                        ["`repeat`"] = true,
                        ["`if`"] = true,
                        ["`for`"] = true,
                        ["`function`"] = true,
                        ["`local`"] = true,
                        ID = true,
                        ["'('"] = true,
                        ["`return`"] = true,
                        ["`break`"] = true,
                        ["%e"] = true,
                    }
                }
                assert.are.same(expected_first, annot.first)
            end)
        end)
    end)
end)