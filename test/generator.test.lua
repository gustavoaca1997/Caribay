local assertions = require"test.assertions"
assert:register("assertion", "contains_error", assertions.contains_error)
assert:register("assertion", "same_ast", assertions.same_ast)
assert:register('assertion', "has_lab", assertions.has_lab)

context("Generator", function()
    setup(function()
        generator = require"caribay.generator"
        re = require"relabel"
        lfs = require"lfs"
        src_parser = require"caribay.parser"
    end)

    context("generates a parser (with possible labels)", function()
        context("from a grammar with", function()
            context("a rule with", function()
                test("a repetition of character class", function()
                    local src1 = 'ALPHA_NUM <- [0-9a-zA-Z]+'
                    local match1 = generator.gen(src1)
                    
                    local src2 = 'alpha_num <- [0-9a-zA-Z]+'
                    local match2 = generator.gen(src2)
                    
                    assert.are.same({ tag = 'ALPHA_NUM', pos = 1, '8aBC3' }, match1('8aBC3'))   
                    assert.are.same({ tag = 'alpha_num', pos = 1, '8', 'a', 'B', 'C', '3' }, match2('8aBC3')) 
                end)
    
                test("a captured literal", function()
                    local src = 's <- "a"'
                    local match = generator.gen(src)
                    local expected = {
                        tag = 's', pos = 1,
                        { tag = 'token', pos = 1, 'a' }
                    }
                    assert.are.same(expected, match('a'))
                    assert.is.falsy(match('aa'))
                    assert.is.falsy(match('aa'))
                    assert.is.falsy(match('b'))
                end)
    
                test("a not captured literal", function()
                    local match = generator.gen("s <- 'a'")
                    assert.are.same({ tag = 's', pos = 1 }, match('a'))
                    assert.is.falsy(match('aa'))
                    assert.is.falsy(match('ab'))
                    assert.is.falsy(match('b'))
                end)
    
                test("a captured literal between two not captured literals", function()
                    local src = [[
                        s <- '->' "a" '<-'
                    ]]
                    local match, labs_arr = generator.gen(src)
    
                    local expected = {
                        tag = 's', pos = 1,
                        { 
                            tag = 'token', pos = 3,
                            'a' 
                        }
                    }
                    assert.are.same(expected, match('->a<-'))
    
                    expected = {
                        tag = 's', pos = 1,
                        { 
                            tag = 'token', pos = 5,
                            'a' 
                        }
                    }
                    assert.are.same(expected, match('->  a<- '))
    
                    expected = {
                        tag = 's', pos = 2,
                        { 
                            tag = 'token', pos = 5,
                            'a' 
                        }
                    }
                    assert.are.same(expected, match(' -> a <- '))
    
                    assert.are.same({'s_<-', 's_a'}, labs_arr)
                    assert.has_lab(match, '->a<--', 'EOF', 6)
                    assert.has_lab(match, '->aa<--', 's_<-', 4)
                    assert.has_lab(match, '-> b <', 's_a', 4)
                end)
    
                test("a not captured literal between two captured literals I", function()
                    local src = [[
                        s <- "{" 'x' "}"
                    ]]
                    local match, labs_arr = generator.gen(src)
    
                    local expected = {
                        tag = 's', pos = 1,
                        { 
                            tag = 'token', pos = 1,
                            '{' 
                        },
                        { 
                            tag = 'token', pos = 3,
                            '}'
                        },
                    }
                    assert.same_ast(expected, match('{x}'))
    
                    expected = {
                        tag = 's', pos = 1,
                        { 
                            tag = 'token', pos = 1,
                            '{' 
                        },
                        { 
                            tag = 'token', pos = 4,
                            '}'
                        },
                    }
                    assert.are.same(expected, match('{x }'))
    
                    expected = {
                        tag = 's', pos = 1,
                        { 
                            tag = 'token', pos = 1,
                            '{' 
                        },
                        { 
                            tag = 'token', pos = 5,
                            '}'
                        },
                    }
                    assert.are.same(expected, match('{  x} '))
    
                    expected = {
                        tag = 's', pos = 2,
                        { 
                            tag = 'token', pos = 2,
                            '{' 
                        },
                        { 
                            tag = 'token', pos = 7,
                            '}'
                        },
                    }
                    assert.are.same(expected, match(' {  x } '))

                    assert.are.same({'s_x', 's_}'}, labs_arr)
                    assert.has_lab(match, '{   x', 's_}', 6)
                    assert.has_lab(match, '{ }', 's_x', 3)
                end)
    
                test("a backslash", function()
                    local src = [[
                        s <- "\\t" "a"
                    ]]
                    local match, labs_arr = generator.gen(src)
                    local input = [[
                        \ta
                    ]]
                    assert.is.truthy(match(input))
                    assert.are.same({'s_a'}, labs_arr)
                    assert.has_lab(match, [[\t]], 's_a', 3)

                end)
    
                test("an ordered choice of literals", function()
                    local src = [[
                        s <- "a" / "b" / "c"
                    ]]
                    local match = generator.gen(src)
                    local expected = {
                        tag = 's',
                        { tag = 'token', 'a' }
                    }
                    assert.same_ast(expected, match'a')
    
                    expected[1][1] = 'b'
                    assert.same_ast(expected, match'b')
    
                    expected[1][1] = 'c'
                    assert.same_ast(expected, match'c')
                end)
    
                test("empty token", function()
                    local src = [[
                        s <- A
                        A <- 'a' (A / %e) 'b'
                    ]]
                    local match = generator.gen(src)
    
                    assert.is.truthy(match('aaabbb'))
                    assert.is.truthy(match('aabb   '))
                    assert.is.truthy(match('   ab'))
                    assert.is.truthy(match('   aaaaabbbbb   '))
                    assert.is.falsy(match('   aaaaabbb bb   '))                    
                end)
    
                test("sequences as ordered choices", function()
                    local src = [[
                        s <- "a" '!' / '{' "b" '}' / '&' "c"
                    ]]
                    local match, labs_arr = generator.gen(src)
                    local expected = {
                        tag = 's',
                        { tag = 'token', 'a' }
                    }
                    assert.same_ast(expected, match('a!'))
                    assert.same_ast(expected, match('a  !'))
    
                    expected[1][1] = 'b'
                    assert.same_ast(expected, match('{ b }'))
                    assert.same_ast(expected, match('{   b }'))
    
                    expected[1][1] = 'c'
                    assert.same_ast(expected, match('&c'))
                    assert.same_ast(expected, match('&   c  '))

                    assert.are.same({'s_!', 's_b', 's_c', 's_}'}, labs_arr)
                    assert.has_lab(match, ' a ', 's_!', 4)
                    assert.has_lab(match, ' {b ) ', 's_}', 5)
                    assert.has_lab(match, '{c} ', 's_b', 2)
                    assert.has_lab(match, '&', 's_c', 2)

                end)
    
                test("usage of initial automatic SKIP", function()
                    local src = [[
                        s <- "a" '!' / '{' "b" '}' / '&' "c"
                    ]]
                    local match, labs_arr = generator.gen(src)
                    local expected = {
                        tag = 's',
                        { tag = 'token', 'a' }
                    }
                    assert.are.same({'s_!', 's_b', 's_c', 's_}'}, labs_arr)

                    assert.same_ast(expected, match(' a!'))
                    assert.same_ast(expected, match('     a  !'))
    
                    expected[1][1] = 'b'
                    assert.same_ast(expected, match(' { b }'))
                    assert.same_ast(expected, match('    {   b }'))
    
                    expected[1][1] = 'c'
                    assert.same_ast(expected, match(' &c'))
                    assert.same_ast(expected, match('   &   c  '))
                end)
    
                test("a recursive syntactic rule", function()
                    local src = [[
                        s <- '{' s '}' / "x"
                    ]]
                    local match, labs_arr = generator.gen(src)
                    
                    local expected = {
                        tag = 's', pos = 3,
                        {
                            tag = 's', pos = 4,
                            {
                                tag = 's', pos = 7,
                                {
                                    tag = 's', pos = 11,
                                    { tag = 'token', pos = 11, 'x' }
                                }
                            }
                        }
                    }
                    assert.are.same(expected, match('  {{  {   x } }   }'))
                    assert.same_ast({ tag = 's', { tag = 'token', 'x' } }, match('x'))
    
                    assert.are.same({'s_s', 's_}'}, labs_arr)
                    assert.has_lab(match, '{  }', 's_s', 4)
                    assert.has_lab(match, '{ x', 's_}', 4)
                end)

            end)
    
            test("three syntactic rules", function()
                local src = [[
                    s <- between_brackets / between_parentheses
    
                    between_brackets    <- '{' "b" '}'
                    between_parentheses <- '(' "p" ')' 
                ]]
                local match, labs_arr = generator.gen(src)
    
                local expected = {
                    tag = 's',
                    {
                        tag = 'between_brackets',
                        { tag = 'token', 'b' },
                    }
                }
                assert.same_ast(expected, match('{b}'))
                assert.same_ast(expected, match('  {     b } '))
    
                expected = {
                    tag = 's',
                    {
                        tag = 'between_parentheses',
                        { tag = 'token', 'p' },
                    }
                }
                assert.same_ast(expected, match('(p)'))
                assert.same_ast(expected, match('( p)   '))
    
                assert.are.same({'between_brackets_b', 'between_brackets_}', 
                    'between_parentheses_)', 'between_parentheses_p'}, labs_arr)
                assert.has_lab(match, '{ p }', 'between_brackets_b', 3)
                assert.has_lab(match, '{  {b }', 'between_brackets_b', 4)
                assert.has_lab(match, '( b )', 'between_parentheses_p', 3)
                assert.has_lab(match, '{ b )', 'between_brackets_}', 5)
                assert.has_lab(match, '( p }', 'between_parentheses_)', 5)
            end)
    
            test("two trivial lexical rules and one initial syntactic rule", function()
                local src = [[
                    full_name <- FIRST LAST
                    FIRST <- 'Gustavo'
                    LAST <- 'Castellanos'
                ]]
                local match, labs_arr = generator.gen(src)
    
                local expected = {
                    tag = 'full_name',
                    { tag = 'FIRST', 'Gustavo' },
                    { tag = 'LAST', 'Castellanos' },
                }
                assert.same_ast(expected, match('GustavoCastellanos'))
                assert.same_ast(expected, match('Gustavo Castellanos'))
                assert.same_ast(expected, match('   Gustavo    Castellanos'))

                assert.are.same({'full_name_LAST'}, labs_arr)
                assert.has_lab(match, 'GustavoC astellanos', 'full_name_LAST', 8)
            end)
    
            test("and predicate", function()
                -- Context-sensitive language {a^n b^n c^n : n >= 1}
                local src = [[
                    s <- &(A 'c') 'a'+ B
                    A <- 'a' A? 'b'
                    B <- 'b' B? 'c'
                ]]
                local match, labs_arr = generator.gen(src)
    
                assert.is.truthy(match('aaabbbccc'))
                assert.is.truthy(match('aaaabbbbcccc  '))
                assert.is.truthy(match(' abc'))
                assert.is.truthy(match('  aaabbbccc'))

                assert.are.same({'s_B'}, labs_arr)

                assert.is.falsy(match('aaabbbbccc'))
                assert.is.falsy(match('aaabbbcc'))
                assert.is.falsy(match('aa abbbccc'))
            end)

            test("Manually inserted error", function()
                local src = [[
                    numbers <- ((INT / HEX / FLOAT)^ErrNumber)+
                    fragment INT <- %d+
                    fragment FLOAT <- %d+ '.' %d+
                    fragment HEX <- '0x' [0-9a-f]+
                ]]
                local match, labs = generator.gen(src)
                assert.are.same({'ErrNumber'}, labs)
                assert.has_lab(match, ' ', 'ErrNumber', 2)
                assert.has_lab(match, 'asdf', 'ErrNumber', 1)
                assert.has_lab(match, '123 32 x 2.45', 'ErrNumber', 8)
            end)
    
            test("list of numbers", function()
                local src = [[
                    list <- NUMBER+
                    NUMBER <- INT / FLOAT
                    INT <- %d+ !'.'
                    FLOAT <- %d+ '.' %d+
                ]]
                local match, labs = generator.gen(src)
    
                local expected = {
                    tag = 'list', pos = 1,
                    {
                        tag = 'NUMBER', pos = 1,
                        '123'
                    },{
                        tag = 'NUMBER', pos = 5,
                        '123123123.3'
                    },{
                        tag = 'NUMBER', pos = 17,
                        '12'
                    },{
                        tag = 'NUMBER', pos = 20,
                        '1.23'
                    },
                }
                assert.are.same(expected, match("123 123123123.3 12 1.23"))
                assert.same_ast(expected, match(" 123   123123123.3   12  1.23   "))
                assert.is.falsy(match("123 12.3121.23"))
            end)
    
            test("syntactic repetition of bits", function()
                local src = [[
                    rand_bits <- BIT+
                    BIT <- '0' / '1'
                ]]
                local match = generator.gen(src)
    
                local expected = {
                    tag = 'rand_bits',
                    { tag = 'BIT', '0' },
                    { tag = 'BIT', '0' },
                    { tag = 'BIT', '1' },
                    { tag = 'BIT', '0' },
                    { tag = 'BIT', '1' },
                }
                assert.same_ast(expected, match('00101'))
                assert.same_ast(expected, match('  00 1         0 1    '))
                assert.same_ast(expected, match(' 0   0 10         1'))
                assert.is.falsy(match(' 00 1 10 1 00 1b 0'))
            end)
    
            test("lexical repetition of bits", function()
                local src = [[
                    rand_bits <- BITS
                    BIT <- '0' / '1'
                    BITS <- BIT+
                ]]
                local match = generator.gen(src)
    
                local expected = {
                    tag = 'rand_bits', {
                        tag = 'BITS', '00101',
                    },
                }
                assert.same_ast(expected, match('00101'))
                assert.same_ast(expected, match('   00101 '))
                assert.is.falsy(match('00 101'))
                assert.is.falsy(match('  00 1         0 1    '))
                assert.is.falsy(match(' 0   0 10         1'))
            end)
    
            test("its own ID_START rule", function()
                local src = [[
                    s <- `print` ID
                    ID_START <- '_'? [a-zA-Z]+  
                ]]
                local match, labs_arr = generator.gen(src)
    
                local input = 'print _private_attr'
                local expected = {
                    tag = 's',
                    { tag = 'token', 'print' },
                    { tag = 'ID', '_private_attr' },
                }
                assert.same_ast(expected, match(input))
                assert.are.same({'s_ID'}, labs_arr)
                assert.has_lab(match, 'print 0is_boolean', 's_ID', 7)
            end)
    
            test("its own ID_END rule", function()
                local src = [[
                    s <- `print` ID
                    ID_END <- [a-zA-Z?]+                
                ]]
                local match, labs_arr = generator.gen(src)
    
                local input = 'print isNumber?'
                local expected = {
                    tag = 's',
                    { tag = 'token', 'print' },
                    { tag = 'ID', 'isNumber?' },
                }
                assert.are.same({'s_ID'}, labs_arr)
                assert.same_ast(expected, match(input))
            end)
    
            test("its own ID_START and ID_END rules", function()
                local src = [[
                    s <- `print` ID
                    ID_START <- '_'? [a-zA-Z]+
                    ID_END <- [a-zA-Z?]+                
                ]]
                local match, labs_arr = generator.gen(src)
    
                local input = 'print _isNumber?'
                local expected = {
                    tag = 's',
                    { tag = 'token', 'print' },
                    { tag = 'ID', '_isNumber?' },
                }
                assert.same_ast(expected, match(input))
                assert.are.same({'s_ID'}, labs_arr)
                assert.is.falsy(match("print _is_boolean?"))
            end)
    
            test("default ID rule and a keyword", function()
                local src = [[
                    s <- (print / assign)+
                    assign <- ID '=' INT
                    INT <- %d+
                    print <- `print` ID
                ]]
                local match, labs_arr = generator.gen(src)
    
                local input = 'x = 10 print x printx = 20 print printx'
                local expected = {
                    tag = 's',
                    {
                        tag = 'assign',
                        { tag = 'ID', 'x' },
                        { tag = 'INT', '10' },
                    },
                    {
                        tag = 'print',
                        { tag = 'token', 'print' },
                        { tag = 'ID', 'x' },
                    },
                    {
                        tag = 'assign',
                        { tag = 'ID', 'printx' },
                        { tag = 'INT', '20' },
                    },
                    {
                        tag = 'print',
                        { tag = 'token', 'print' },
                        { tag = 'ID', 'printx' },
                    },
                }
                assert.same_ast(expected, match(input))

                assert.are.same({'assign_INT', 'print_ID'}, labs_arr)
                assert.has_lab(match, 'x = print 2', 'assign_INT', 5)
                assert.has_lab(match, 'print 2', 'print_ID', 7)
                assert.has_lab(match, '= x = 10', 'fail', 1)
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
                local match, labs_arr = generator.gen(src)
    
                local input = [[
                vector3 vector3D
                ;;;;
                vector3D.2
                ]]
                local expected = {
                    tag = 's', pos = 17,
                    {
                        tag = 'init', pos = 17,
                        { tag = 'VECTOR', pos = 17, 'vector3' },
                        { tag = 'ID', pos = 25, 'vector3D' },
                    },
                    {
                        tag = 'idx', pos = 71,
                        { tag = 'ID', pos = 71, 'vector3D' },
                        { tag = 'INT', pos = 80, '2' },
                    },
                }
                assert.are.same(expected, match(input))

                assert.are.same({ 'idx_INT', 'init_ID',}, labs_arr)
                assert.has_lab(match, 'vector3D 2', 'fail', 10)
                assert.has_lab(match, 'vector3 vector3D ;;.; vector3D.2', 'EOF', 20)
                assert.has_lab(match, 'vector1 3dvector', 'init_ID', 9)
            end)
    
            test('syntactic fragment', function()
                local src = [[
                    assign <- ID '=' number
                    fragment number <- FLOAT / INT
                    INT <- %d+
                    FLOAT <- %d+ '.' %d+
                ]]
                local match = generator.gen(src)
    
                assert.same_ast({ 
                    tag = 'assign', 
                    { tag = 'ID', 'x' }, 
                    { tag = 'INT', '255' } 
                }, match[[  x  = 255 ]])
    
                assert.same_ast({
                    tag = 'assign',
                    { tag = 'ID', 'a_2' },
                    { tag = 'FLOAT', '3.1416' },
                }, match[[a_2        =3.1416 ]])
            end)
    
            test("fragment keyword and its own SKIP rule", function()
                local src = [[
                    s <- (init / idx)+
                    init <- TYPE ID
                    idx <- ID '.' INT
    
                    TYPE <- `map` / VECTOR
                    fragment keyword VECTOR <- 'vector' [1-9]
                    INT <- %d+
    
                    SKIP <- (' ' / '\n' / ';')*
                ]]
                local match = generator.gen(src)
    
                local input = [[
                    map map_0
                    map_0.5;
    
                    vector3 vector3D
                    vector3D.2;
                ]]
                local expected = {
                    tag = 's',
                    {
                        tag = 'init',
                        { tag = 'TYPE', 'map' },
                        { tag = 'ID', 'map_0' },
                    },
                    {
                        tag = 'idx',
                        { tag = 'ID', 'map_0' },
                        { tag = 'INT', '5' },
                    },
                    {
                        tag = 'init',
                        { tag = 'TYPE', 'vector3' },
                        { tag = 'ID', 'vector3D' },
                    },
                    {
                        tag = 'idx',
                        { tag = 'ID', 'vector3D' },
                        { tag = 'INT', '2' },
                    },
                }
                assert.same_ast(expected, match(input))
            end)
    
            test("user defined `COMMENT`", function()
                local src = [[
                    s <- NUMBER (',' NUMBER)*
                    COMMENT <- '--' [^%nl]*
                    NUMBER <- %d+
                ]]
                local match, labs_arr = generator.gen(src)
    
                local input = [[
                    -- a test
                    5, -- a number
                    6, 7, -- this number is not captured 8
                    9
                ]]
                local expected = {
                    tag = 's',
                    { tag = 'NUMBER', '5' },
                    { tag = 'NUMBER', '6' },
                    { tag = 'NUMBER', '7' },
                    { tag = 'NUMBER', '9' },
                }
                assert.same_ast(expected, match(input))

                assert.are.same({'s_NUMBER',}, labs_arr)
                assert.has_lab(match, '543 , x', 's_NUMBER', 7)
            end)
    
            test("a syntactic named group", function()
                local src = [[
                    s <- { "="* : equals} =equals
                ]]
                local match = generator.gen(src)
                assert.same_ast({ 
                    tag = "s", 
                    { tag = "token", "=" }, 
                    { tag = "token", "=" },
                    { tag = "token", "=" },
                    { tag = "token", "=" },
                }, match("===="))
            end)

            test("an annotable ordered choice and repeated annotable token", function()
                local src = [[
                    s <- '>' '|' (ID+ / NUMBER+) (';'* / ','*) '|'
                    NUMBER <- %d+
                ]]
                local match, labs_arr = generator.gen(src)
                assert.are.same({
                    's_ord_exp', 
                    's_|', 
                    's_|_2'
                }, labs_arr)
                assert.is.truthy(match('> | epa32 blabla bla_bla ;;;; |'))
            end)
           
        end)
    
        test("from JSON grammar", function()
            local f = assert(io.open("./test/expected/json/grammar.peg", "r"))
            local src = f:read("a")
            local match, labs_arr = generator.gen(src)
            f:close()

            assert.are.same({
                'array_]',
                'object_}', 
                'pair_value',
            }, labs_arr)
    
            local f1 = assert(io.open("./test/expected/json/examples/example1.json"))
            local input = f1:read("a")
            local expected = require"test.expected.json.examples.output1"
            assert.same_ast(expected, match(input))
            f1:close()
        end)
    
        test("from Lua grammar", function()
            local f = assert(io.open("./test/expected/lua/grammar.peg", "r"))
            local src = f:read("a")
            local match, labs_arr = generator.gen(src, {
                check_eq = function(subject, pos, closing, opening)
                    return #closing[1] == #opening[1]
                end,
                always_true = function(s, i, x)
                    print('auxilio', x, re.calcline(s, i))
                    return true
                end
            })
            f:close()
    
            --TODO: Test `labs_arr`

            -- Case 1:
            local input = [[
                _x_10 = 10
                return _x_10;
            ]]
            local expected = require"test.expected.lua.examples.output1"
            local ast, err, pos = match(input)
            assert.same_ast(expected, ast)
    
            -- Case 2:
            input = [==[
                return [=[aa]=]
            ]==]
    
            expected = {
                tag = 'program',
                {
                    tag = 'chunk',
                    {
                        tag = 'laststat',
                        { tag = 'token', 'return' },
                        {
                            tag = 'explist',
                            {
                                tag = 'exp',
                                { tag = 'STRING', '[=[aa]=]' }
                            }
                        }
                    }
                }
            }
            assert.same_ast(expected, match(input))
    
            -- Case 3:
            input = [[
                return 'abc' .. "def"
            ]]
            ast, err, pos = match(input)
            if not ast then print('abcdef', re.calcline(input, pos)) end
            assert.is.truthy(match(input))
    
            -- Case 4:
            input = [[x = 4 + x/2]]
            expected = require"test.expected.lua.examples.output2"
            -- src_parser.show_ast(match(input))
            assert.same_ast(expected, match(input))
    
            -- Other cases:
            local folder_name = [[./test/lua5.1-tests/]]
            for file_name in lfs.dir(folder_name) do
                if file_name ~= '.' and file_name ~= '..' then
                    f = assert(io.open(folder_name .. file_name, "r"))
                    local input = assert(f:read("a"))
    
                    local ast, err, pos = match(input)
                    if not ast then print('\n' .. folder_name .. file_name, err, re.calcline(input, pos) ) end
                    assert.is.truthy(ast)
                    f:close()
                end
            end
        end)
    
        context("that reports when", function()
            test("lexical sequence tries to match syntactic sequence", function()
                local src = [[
                    S <- '(' "b" ')'
                ]]
                local match = generator.gen(src)
                assert.is.truthy(match('(b)'))
                assert.is.truthy(match('  (b)'))
                assert.is.falsy(match('( b )'))
                assert.is.falsy(match('(b)  '))
            end)
    
            test("use regular literal as keyword", function()
                local src = [[
                    s <- (print / assign)+
                    assign <- ID '=' INT
                    INT <- %d+
                    print <- "print" ID
                ]]
                local match = generator.gen(src)
    
                local input = 'x = 10 print x printx = 20 print printx'
                assert.is.falsy(match(input))
            end)
    
            test("use regular lex rule as keyword rule", function()
                local src = [[
                    s <- (init / idx)+
                    init <- VECTOR ID
                    idx <- ID '.' INT
    
                    VECTOR <- 'vector' [1-9]
                    INT <- %d+
    
                    SKIP <- (' ' / '\n' / ';')*
                ]]
                local match = generator.gen(src)
    
                local input = [[
                    vector3 vector3D;
                    vector3D.2;
                ]]
                assert.is.falsy(match(input))
            end)
        end)
    end)

    -- This one only tests labels generated and not successfu
    context("generates labels for a parser using unique context with ", function()
        test("a disjoint ordered choice", function()
            -- The alternatives of this choice are disjoint.
            -- The choice must succeed, since that the start rule
            -- must succeed.
            -- After matching a symbol in the FIRST set of the the first
            -- alternative the matching of first alternative must succeed.
            -- As the choice must succeed, the last alternative must succeed
            -- when we try to match it.
            local src = [[
                s <- 'a' 'c' / 'c' 'd'
            ]]
            local match, labs_arr = generator.gen(src, nil, true)
            
            assert.are.same({'s_c', 's_d'}, labs_arr)
            assert.has_lab(match, 'a', 's_c', 2)
            assert.has_lab(match, 'a d', 's_c', 3)
            assert.has_lab(match, 'd', 'fail', 1)
            assert.has_lab(match, 'c', 's_d', 2)
            assert.has_lab(match, 'c c', 's_d', 3)
        end)

        test("default ID rule and a keyword", function()
            local src = [[
                s <- (print / assign)+
                assign <- ID '=' INT
                INT <- %d+
                print <- `print` ID
            ]]
            local match, labs_arr = generator.gen(src, nil, true)

            local input = 'x = 10 print x printx = 20 print printx'
            local expected = {
                tag = 's',
                {
                    tag = 'assign',
                    { tag = 'ID', 'x' },
                    { tag = 'INT', '10' },
                },
                {
                    tag = 'print',
                    { tag = 'token', 'print' },
                    { tag = 'ID', 'x' },
                },
                {
                    tag = 'assign',
                    { tag = 'ID', 'printx' },
                    { tag = 'INT', '20' },
                },
                {
                    tag = 'print',
                    { tag = 'token', 'print' },
                    { tag = 'ID', 'printx' },
                },
            }
            assert.same_ast(expected, match(input))

            assert.are.same({'assign_=', 'assign_INT', 'print_ID'}, labs_arr)
            assert.has_lab(match, 'x 10', 'assign_=', 3)
            assert.has_lab(match, 'x = print 2', 'assign_INT', 5)
            assert.has_lab(match, 'print 2', 'print_ID', 7)
            assert.has_lab(match, '= x = 10', 'fail', 1)
        end)

        test("default ID rule, a keyword and a manually inserted label I", function()
            local src = [[
                s <- (print / assign)+
                assign <- ID '=' INT^ErrorInt
                INT <- %d+
                print <- `print` ID
            ]]
            local match, labs_arr = generator.gen(src, nil, true)

            local input = 'x = 10 print x printx = 20 print printx'
            local expected = {
                tag = 's',
                {
                    tag = 'assign',
                    { tag = 'ID', 'x' },
                    { tag = 'INT', '10' },
                },
                {
                    tag = 'print',
                    { tag = 'token', 'print' },
                    { tag = 'ID', 'x' },
                },
                {
                    tag = 'assign',
                    { tag = 'ID', 'printx' },
                    { tag = 'INT', '20' },
                },
                {
                    tag = 'print',
                    { tag = 'token', 'print' },
                    { tag = 'ID', 'printx' },
                },
            }
            assert.same_ast(expected, match(input))

            assert.are.same({'ErrorInt', 'assign_=', 'print_ID'}, labs_arr)
            assert.has_lab(match, 'x 10', 'assign_=', 3)
            assert.has_lab(match, 'x = print 2', 'ErrorInt', 5)
            assert.has_lab(match, 'print 2', 'print_ID', 7)
            assert.has_lab(match, '= x = 10', 'fail', 1)
        end)

        test("default ID rule , a keyword and a manually inserted label II", function()
            local src = [[
                s <- (print / assign)+
                assign <- ID '=' ('0b' BIN / INT / FLOAT)^ErrorNumber
                INT <- %d+
                FLOAT <- %d+ '.' %d+
                BIN <- ('0' / '1')+
                print <- `print` ID
            ]]
            local match, labs_arr = generator.gen(src, nil, true)
            assert.are.same({'ErrorNumber', 'assign_=', 'assign_BIN', 'print_ID'}, labs_arr)
            
            local input = [[
                x = 0b0011101 print x printx = 20 print printx
            ]]
            print(match(input))
            assert.is_truthy(match(input))

            assert.has_lab(match, 'x 10', 'assign_=', 3)
            assert.has_lab(match, 'x = print 2', 'ErrorNumber', 5)
            assert.has_lab(match, 'print 2', 'print_ID', 7)
            assert.has_lab(match, '= x = 10', 'fail', 1)
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
            local match, labs_arr = generator.gen(src, nil, true)

            local input = [[
            vector3 vector3D
            ;;;;
            vector3D.2
            ]]
            local expected = {
                tag = 's', pos = 17,
                {
                    tag = 'init', pos = 17,
                    { tag = 'VECTOR', pos = 17, 'vector3' },
                    { tag = 'ID', pos = 25, 'vector3D' },
                },
                {
                    tag = 'idx', pos = 71,
                    { tag = 'ID', pos = 71, 'vector3D' },
                    { tag = 'INT', pos = 80, '2' },
                },
            }
            assert.same_ast(expected, match(input))

            assert.are.same({'idx_.', 'idx_INT', 'init_ID',}, labs_arr)
            assert.has_lab(match, 'vector3D 2', 'idx_.', 10)
            assert.has_lab(match, 'vector3 vector3D ;;.; vector3D.2', 'EOF', 20)
            assert.has_lab(match, 'vector1 3dvector', 'init_ID', 9)
        end)
    end)

    pending("generates labels for a parser using unique context and unique syntactical symbols with ", function()
        pending("a disjoint ordered choice", function()
            -- The alternatives of this choice are disjoint.
            -- The choice must succeed, since that the start rule
            -- must succeed.
            -- After matching a symbol in the FIRST set of the the first
            -- alternative the matching of first alternative must succeed.
            -- As the choice must succeed, the last alternative must succeed
            -- when we try to match it.
            local src = [[
                s <- 'a' 'c' / 'c' 'd'
            ]]
            local match, labs_arr = generator.gen(src, nil, true)
            
            assert.are.same({'s_c', 's_c_2', 's_d'}, labs_arr)
            assert.has_lab(match, 'a', 's_c', 2)
            assert.has_lab(match, 'a d', 's_c', 3)
            assert.has_lab(match, 'd', 'fail', 1)
            assert.has_lab(match, 'c', 's_d', 2)
            assert.has_lab(match, 'c c', 's_d', 3)
        end)

        pending("a not disjoint ordered choice", function()
            -- The alternatives of this choice are not disjoint.
            -- Given that the start rule must succeed, the choice
            -- must succeed. Thus, the last alternative of this
            -- choice must succeed.
            local src = [[
                s <- 'a' 'b' / 'a' 'c'
            ]]
            local match, labs_arr = generator.gen(src)

            assert.are.same({'s_a', 's_c', }, labs_arr)
            assert.has_lab(match, 'a', 's_c', 2)
            assert.has_lab(match, 'a d', 's_c', 3)
            assert.has_lab(match, 'c', 'fail', 1)
        end)
    end)

    context("generates recovery rules (if enabled) when adding labels", function()
        context("from a grammar with", function()
            test("default ID rule and a keyword using terror", function()
                local src = [[
                    s <- (print / assign)+
                    assign <- ID '=' INT
                    INT <- %d+
                    print <- `print` ID
                ]]
                local match, labs_arr = generator.gen(src, nil, true, true)
                assert.are.same({'assign_=', 'assign_INT', 'print_ID'}, labs_arr)
                
                local terror = {
                    ['assign_='] = "Missing '=' in assignment",
                    ['assign_INT'] = "Integer expected",
                    ['print_ID'] = "Valid identifier expected",
                    fail = 'Parsing failed',
                }
                local input = [[
                    x = 10
                    y   11
                    z =
                    print 2
                ]]
                local expected_errors = {
                    {
                        line = 2,
                        col = 25,
                        msg = "Missing '=' in assignment",
                    },
                    {
                        line = 4,
                        col = 21,
                        msg = "Integer expected",
                    },
                    {
                        line = 4,
                        col = 27,
                        msg = "Valid identifier expected",
                    },

                }

                local b, errors = match(input, terror)
                assert.is_false(b)
                assert.are.same(expected_errors, errors)
            end)

            test("default ID rule and a keyword with ordered choice using terror", function()
                local src = [[
                    s <- (print / assign)+
                    assign <- ID '=' (INT / ID)
                    INT <- %d+
                    FLOAT <- %d+ '.' %d+
                    print <- `print` ID
                ]]
                local match, labs_arr = generator.gen(src, nil, true, true)
                assert.are.same({'assign_=', 'assign_ord_exp', 'print_ID'}, labs_arr)
                
                local terror = {
                    ['assign_='] = "Missing '=' in assignment",
                    ['assign_ord_exp'] = "RValue expected",
                    ['print_ID'] = "Valid identifier expected",
                    fail = 'Parsing failed',
                }

                -----------------------------------------
                -- Case 1: Successfull parsing
                local input = [[
                    x = 10 
                    print x 
                    printx = 20 
                    x = printx
                    print printx
                ]]
                local expected = {
                    tag = 's',
                    {
                        tag = 'assign',
                        { tag = 'ID', 'x' },
                        { tag = 'INT', '10' },
                    },
                    {
                        tag = 'print',
                        { tag = 'token', 'print' },
                        { tag = 'ID', 'x' },
                    },
                    {
                        tag = 'assign',
                        { tag = 'ID', 'printx' },
                        { tag = 'INT', '20' },
                    },
                    {
                        tag = 'assign',
                        { tag = 'ID', 'x' },
                        { tag = 'ID', 'printx' },
                    },
                    {
                        tag = 'print',
                        { tag = 'token', 'print' },
                        { tag = 'ID', 'printx' },
                    },
                }
                assert.same_ast(expected, match(input, terror))

                -----------------------------------------
                -- Case 2: Failed parsing
                input = [[
                    x = 10
                    y   11
                    z =
                    print 2
                ]]
                expected = {
                    {
                        line = 2,
                        col = 25,
                        msg = "Missing '=' in assignment",
                    },
                    {
                        line = 4,
                        col = 21,
                        msg = "RValue expected",
                    },
                    {
                        line = 4,
                        col = 27,
                        msg = "Valid identifier expected",
                    },

                }
                local b, errors = match(input, terror)
                assert.is_false(b)
                assert.are.same(expected, errors)
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
                local match, labs_arr = generator.gen(src, nil, true, true)
                assert.are.same({'idx_.', 'idx_INT', 'init_ID',}, labs_arr)
    
                -----------------------------------------
                -- Case 1: Successfull parsing
                local input = [[
                vector3 vector3D
                ;;;;
                vector3D.2
                ]]
                local expected = {
                    tag = 's', pos = 17,
                    {
                        tag = 'init', pos = 17,
                        { tag = 'VECTOR', pos = 17, 'vector3' },
                        { tag = 'ID', pos = 25, 'vector3D' },
                    },
                    {
                        tag = 'idx', pos = 71,
                        { tag = 'ID', pos = 71, 'vector3D' },
                        { tag = 'INT', pos = 80, '2' },
                    },
                }
                assert.same_ast(expected, match(input))

                -----------------------------------------
                -- Case 2: Failed parsing
                input = [[
                    vector3.
                    vector3D.2D,
                    vector3D.2
                ]]
                
                expected = {
                    {
                        line = 1,
                        col = 28,
                        msg = 'init_ID',
                    },
                    {
                        line = 2,
                        col = 32,
                        msg = 'idx_.',
                    }
                }
                local b, errors = match(input)
                assert.is_false(b)
                assert.are.same(expected, errors)
            end)
        end)

        test("from JSON grammar", function()
            local f = assert(io.open("./test/expected/json/grammar.peg", "r"))
            local src = f:read("a")
            local match, labs_arr = generator.gen(src, nil, true, true)
            f:close()

            assert.are.same({
                'array_]',
                'object_}', 
                'pair_value',
            }, labs_arr)
    
            local f1 = assert(io.open("./test/expected/json/examples/example1.json"))
            local input = f1:read("a")
            local expected = require"test.expected.json.examples.output1"
            assert.same_ast(expected, match(input))
            f1:close()
        end)
    
        test("from Lua grammar", function()
            local f = assert(io.open("./test/expected/lua/grammar.peg", "r"))
            local src = f:read("a")
            local match, labs_arr = generator.gen(src, {
                check_eq = function(subject, pos, closing, opening)
                    return #closing[1] == #opening[1]
                end,
            }, true, true)
            f:close()
    
            --TODO: Test `labs_arr`

            -- Case 1:
            local input = [[
                _x_10 = 10
                return _x_10;
            ]]
            local expected = require"test.expected.lua.examples.output1"
            local ast, err, pos = match(input)
            assert.same_ast(expected, ast)
    
            -- Case 2:
            input = [==[
                return [=[aa]=]
            ]==]
    
            expected = {
                tag = 'program',
                {
                    tag = 'chunk',
                    {
                        tag = 'laststat',
                        { tag = 'token', 'return' },
                        {
                            tag = 'explist',
                            {
                                tag = 'exp',
                                { tag = 'STRING', '[=[aa]=]' }
                            }
                        }
                    }
                }
            }
            assert.same_ast(expected, match(input))
    
            -- Case 3:
            input = [[
                return 'abc' .. "def"
            ]]
            ast, err, pos = match(input)
            if not ast then print('abcdef', re.calcline(input, pos)) end
            assert.is.truthy(match(input))
    
            -- Case 4:
            input = [[x = 4 + x/2]]
            expected = require"test.expected.lua.examples.output2"
            -- src_parser.show_ast(match(input))
            assert.same_ast(expected, match(input))
    
            -- Other cases:
            local folder_name = [[./test/lua5.1-tests/]]
            for file_name in lfs.dir(folder_name) do
                if file_name ~= '.' and file_name ~= '..' then
                    f = assert(io.open(folder_name .. file_name, "r"))
                    local input = assert(f:read("a"))
    
                    local ast, err, pos = match(input)
                    if not ast then print('\n' .. folder_name .. file_name, err, re.calcline(input, pos) ) end
                    assert.is.truthy(ast)
                    f:close()
                end
            end
        end)
    end)

    test("ensures unique token prefix", function()
        local src = [[
            s <- (`do` / `double`) ("=" / "==") ("<" / "<=") (GT / ">=") (INT / `int16` / `int32` / `int64`)
            INT <- `int`
            GT <- '>'
        ]]
        local match = generator.gen(src)

        assert.is.truthy(match('do = < > int'))
        assert.is.truthy(match('double = < >= int32'))
        assert.is.truthy(match('do == <= > int16'))
        assert.is.truthy(match('double = <= > int64'))

        local input = 'double == <= >= int32'
        local expected = {
            tag = 's',
            { tag = 'token', 'double' },
            { tag = 'token', '==' },
            { tag = 'token', '<=' },
            { tag = 'token', '>=' },
            { tag = 'token', 'int32' },
        }
        local ast, err, pos = match(input)
        assert.same_ast(expected, ast)
    end)

    context("throws", function()
        test("'Not defined'", function()
            local src = [[
                s <- SKIP "a" (star / '+')
            ]]
            local fn = function()
                generator.gen(src)
            end
            assert.has_error(fn, "rule 'star' undefined in given grammar")
        end)

        test("'Error labels inside lexical rules are forbidden'", function()
            local src = [[
                list <- NUMBER+
                NUMBER <- INT / FLOAT
                INT <- %d+ !'.'
                FLOAT <- %d+ '.' %d+^ErrDecimal
            ]]
            local fn = function()
                generator.gen(src)
            end
            assert.has_error(fn, "Rule FLOAT: Error labels inside lexical rules are forbidden")
        end)

        test("'Trying to use a syntactic element in a lexical rule'", function ( )
            local src = [[
                S <- s
                s <- 'a' / 'b'
            ]]
            local fn = function()
                generator.gen(src)
            end
            assert.has_error(fn, "Rule S: Trying to use a syntactic element in a lexical rule")
        end)
    end)
end)