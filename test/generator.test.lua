local assertions = require"test.assertions"
assert:register("assertion", "contains_error", assertions.contains_error)
assert:register("assertion", "same_ast", assertions.same_ast)

context("Generator", function()
    setup(function()
        generator = require"src.generator"
        re = require"relabel"
        lfs = require"lfs"
    end)

    context("generates a parser from a grammar with", function()
        context("a rule with", function()
            test("a captured literal", function()
                local src = 's <- "a"'
                local parser = generator.gen(src)
                local expected = {
                    tag = 's', pos = 1,
                    { tag = 'token', pos = 1, 'a' }
                }
                assert.are.same(expected, parser:match('a'))
                assert.is.falsy(parser:match('aa'))
                assert.is.falsy(parser:match('aa'))
                assert.is.falsy(parser:match('b'))
            end)

            test("a not captured literal", function()
                local parser = generator.gen("s <- 'a'")
                assert.are.same({ tag = 's', pos = 1 }, parser:match('a'))
                assert.is.falsy(parser:match('aa'))
                assert.is.falsy(parser:match('ab'))
                assert.is.falsy(parser:match('b'))
            end)

            test("a captured literal between two not captured literals", function()
                local src = [[
                    s <- '->' "a" '<-'
                ]]
                local parser = generator.gen(src)

                local expected = {
                    tag = 's', pos = 1,
                    { 
                        tag = 'token', pos = 3,
                        'a' 
                    }
                }
                assert.are.same(expected, parser:match('->a<-'))

                expected = {
                    tag = 's', pos = 1,
                    { 
                        tag = 'token', pos = 5,
                        'a' 
                    }
                }
                assert.are.same(expected, parser:match('->  a<- '))

                expected = {
                    tag = 's', pos = 2,
                    { 
                        tag = 'token', pos = 5,
                        'a' 
                    }
                }
                assert.are.same(expected, parser:match(' -> a <- '))

                assert.is.falsy(parser:match('->a<--'))
                assert.is.falsy(parser:match('->a<--'))
                assert.is.falsy(parser:match('->a<--'))
                assert.is.falsy(parser:match('->aa<--'))
                assert.is.falsy(parser:match('-> b <'))
            end)

            test("a not captured literal between two captured literals I", function()
                local src = [[
                    s <- "{" 'x' "}"
                ]]
                local parser = generator.gen(src)

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
                assert.same_ast(expected, parser:match('{x}'))

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
                assert.are.same(expected, parser:match('{x }'))

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
                assert.are.same(expected, parser:match('{  x} '))

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
                assert.are.same(expected, parser:match(' {  x } '))
            end)

            test("an ordered choice of literals", function()
                local src = [[
                    s <- "a" / "b" / "c"
                ]]
                local parser = generator.gen(src)
                local expected = {
                    tag = 's',
                    { tag = 'token', 'a' }
                }
                assert.same_ast(expected, parser:match'a')

                expected[1][1] = 'b'
                assert.same_ast(expected, parser:match'b')

                expected[1][1] = 'c'
                assert.same_ast(expected, parser:match'c')
            end)

            test("empty token", function()
                local src = [[
                    s <- A
                    fragment A <- 'a' (A / %e) 'b'
                ]]
                local parser = generator.gen(src)

                assert.is.truthy(parser:match('aaabbb'))
                assert.is.truthy(parser:match('aabb   '))
                assert.is.truthy(parser:match('   ab'))
                assert.is.truthy(parser:match('   aaaaabbbbb   '))
                assert.is.falsy(parser:match('   aaaaabbb bb   '))
            end)

            test("sequences as ordered choices", function()
                local src = [[
                    s <- "a" '!' / '{' "b" '}' / '&' "c"
                ]]
                local parser = generator.gen(src)
                local expected = {
                    tag = 's',
                    { tag = 'token', 'a' }
                }
                assert.same_ast(expected, parser:match('a!'))
                assert.same_ast(expected, parser:match('a  !'))

                expected[1][1] = 'b'
                assert.same_ast(expected, parser:match('{ b }'))
                assert.same_ast(expected, parser:match('{   b }'))

                expected[1][1] = 'c'
                assert.same_ast(expected, parser:match('&c'))
                assert.same_ast(expected, parser:match('&   c  '))
            end)

            test("usage of initial automatic SKIP", function()
                local src = [[
                    s <- "a" '!' / '{' "b" '}' / '&' "c"
                ]]
                local parser = generator.gen(src)
                local expected = {
                    tag = 's',
                    { tag = 'token', 'a' }
                }
                assert.same_ast(expected, parser:match(' a!'))
                assert.same_ast(expected, parser:match('     a  !'))

                expected[1][1] = 'b'
                assert.same_ast(expected, parser:match(' { b }'))
                assert.same_ast(expected, parser:match('    {   b }'))

                expected[1][1] = 'c'
                assert.same_ast(expected, parser:match(' &c'))
                assert.same_ast(expected, parser:match('   &   c  '))
            end)

            test("a recursive syntactic rule", function()
                local src = [[
                    s <- '{' s '}' / "x"
                ]]
                local parser = generator.gen(src)
                
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
                assert.are.same(expected, parser:match('  {{  {   x } }   }'))
                assert.same_ast({ tag = 's', { tag = 'token', 'x' } }, parser:match('x'))

                assert.is.falsy(parser:match('{ x'))
                assert.is.falsy(parser:match('{ x'))
                assert.is.falsy(parser:match('{  }'))
            end)
        end)

        test("three syntactic rules", function()
            local src = [[
                s <- between_brackets / between_parentheses

                between_brackets    <- '{' "b" '}'
                between_parentheses <- '(' "p" ')' 
            ]]
            local parser = generator.gen(src)

            local expected = {
                tag = 's',
                {
                    tag = 'between_brackets',
                    { tag = 'token', 'b' },
                }
            }
            assert.same_ast(expected, parser:match('{b}'))
            assert.same_ast(expected, parser:match('  {     b } '))

            expected = {
                tag = 's',
                {
                    tag = 'between_parentheses',
                    { tag = 'token', 'p' },
                }
            }
            assert.same_ast(expected, parser:match('(p)'))
            assert.same_ast(expected, parser:match('( p)   '))

            assert.are.falsy(parser:match('{ p }'))
            assert.are.falsy(parser:match('{  {p }'))
            assert.are.falsy(parser:match('( b )'))
            assert.are.falsy(parser:match('{ p )'))
            assert.are.falsy(parser:match('( b }'))
        end)

        test("two trivial lexical rules and one initial syntactic rule", function()
            local src = [[
                full_name <- FIRST LAST
                FIRST <- 'Gustavo'
                LAST <- 'Castellanos'
            ]]
            local parser = generator.gen(src)

            local expected = {
                tag = 'full_name',
                { tag = 'FIRST', 'Gustavo' },
                { tag = 'LAST', 'Castellanos' },
            }
            assert.same_ast(expected, parser:match('GustavoCastellanos'))
            assert.same_ast(expected, parser:match('Gustavo Castellanos'))
            assert.same_ast(expected, parser:match('   Gustavo    Castellanos'))
            assert.is.falsy(parser:match('GustavoC astellanos'))
        end)

        test("and predicate", function()
            -- Non-context free language {a^n b^n c^n : n >= 1}
            local src = [[
                s <- &(A 'c') 'a'+ B
                fragment A <- 'a' A? 'b'
                fragment B <- 'b' B? 'c'
            ]]
            local parser = generator.gen(src)

            assert.is.truthy(parser:match('aaabbbccc'))
            assert.is.truthy(parser:match('aaaabbbbcccc  '))
            assert.is.truthy(parser:match(' abc'))
            assert.is.truthy(parser:match('  aaabbbccc'))
            assert.is.falsy(parser:match('aaabbbbccc'))
            assert.is.falsy(parser:match('aaabbbcc'))
            assert.is.falsy(parser:match('aa abbbccc'))
        end)

        test("some fragments", function()
            local src = [[
                list <- NUMBER+
                NUMBER <- INT / FLOAT
                fragment INT <- %d+ !'.'
                fragment FLOAT <- %d+ '.' %d+
            ]]
            local parser = generator.gen(src)

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
            assert.are.same(expected, parser:match("123 123123123.3 12 1.23"))
            assert.same_ast(expected, parser:match(" 123   123123123.3   12  1.23   "))
            assert.is.falsy(parser:match("123 12.3121.23"))
        end)

        test("syntactic repetition of bits", function()
            local src = [[
                rand_bits <- BIT+
                BIT <- '0' / '1'
            ]]
            local parser = generator.gen(src)

            local expected = {
                tag = 'rand_bits',
                { tag = 'BIT', '0' },
                { tag = 'BIT', '0' },
                { tag = 'BIT', '1' },
                { tag = 'BIT', '0' },
                { tag = 'BIT', '1' },
            }
            assert.same_ast(expected, parser:match('00101'))
            assert.same_ast(expected, parser:match('  00 1         0 1    '))
            assert.same_ast(expected, parser:match(' 0   0 10         1'))
            assert.is.falsy(parser:match(' 00 1 10 1 00 1b 0'))
        end)

        test("lexical repetition of bits", function()
            local src = [[
                fragment BIT <- '0' / '1'
                rand_bits <- BITS
                BITS <- BIT+
            ]]
            local parser = generator.gen(src)

            local expected = {
                tag = 'rand_bits',
                { tag = 'BITS', '00101'}
            }
            assert.same_ast(expected, parser:match('00101'))
            assert.same_ast(expected, parser:match('   00101 '))
            assert.is.falsy(parser:match('00 101'))
            assert.is.falsy(parser:match('  00 1         0 1    '))
            assert.is.falsy(parser:match(' 0   0 10         1'))
        end)

        test("its own ID_START rule", function()
            local src = [[
                s <- `print` ID
                ID_START <- '_'? [a-zA-Z]+                
            ]]
            local parser = generator.gen(src)

            local input = 'print _private_attr'
            local expected = {
                tag = 's',
                { tag = 'token', 'print' },
                { tag = 'ID', '_private_attr' },
            }
            assert.same_ast(expected, parser:match(input))
            assert.is.falsy(parser:match("print 0is_boolean"))
        end)

        test("its own ID_END rule", function()
            local src = [[
                s <- `print` ID
                ID_END <- [a-zA-Z?]+                
            ]]
            local parser = generator.gen(src)

            local input = 'print isNumber?'
            local expected = {
                tag = 's',
                { tag = 'token', 'print' },
                { tag = 'ID', 'isNumber?' },
            }
            assert.same_ast(expected, parser:match(input))
            assert.is.falsy(parser:match("print is_boolean?"))
        end)

        test("its own ID_START and ID_END rules", function()
            local src = [[
                s <- `print` ID
                ID_START <- '_'? [a-zA-Z]+
                ID_END <- [a-zA-Z?]+                
            ]]
            local parser = generator.gen(src)

            local input = 'print _isNumber?'
            local expected = {
                tag = 's',
                { tag = 'token', 'print' },
                { tag = 'ID', '_isNumber?' },
            }
            assert.same_ast(expected, parser:match(input))
            assert.is.falsy(parser:match("print _is_boolean?"))
        end)

        test("default ID rule and a keyword", function()
            local src = [[
                s <- (print / assign)+
                assign <- ID '=' INT
                INT <- %d+
                print <- `print` ID
            ]]
            local parser = generator.gen(src)

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
            assert.same_ast(expected, parser:match(input))
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
            local parser = generator.gen(src)

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
            assert.are.same(expected, parser:match(input))
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
            local parser = generator.gen(src)

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
            assert.same_ast(expected, parser:match(input))
        end)

        test("user defined `COMMENT`", function()
            local src = [[
                s <- NUMBER (',' NUMBER)*
                fragment COMMENT <- '--' [^%nl]*
                NUMBER <- %d+
            ]]
            local parser = generator.gen(src)

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
            -- local ast, err, pos = parser:match(input)
            -- if not ast then
            --     print(err, re.calcline(input, pos))
            -- end
            assert.same_ast(expected, parser:match(input))
        end)

    end)

    pending("generates a parser from expression grammar", function()
        local src = [[
            program <-  (cmd / exp)*
            cmd     <-  ID assign_sign exp
            exp     <-  term ('+' term)*
            term    <~  factor ('*' factor)*
            factor  <~  ID / NUMBER / '(' exp ')'
            NUMBER  <-  %d+ ('.' %d+)?
        ]]
    end)

    test("generates a parser from JSON grammar", function()
        local f = assert(io.open("./test/expected/json/grammar.peg", "r"))
        local src = f:read("a")
        local parser = generator.gen(src)
        f:close()

        local f1 = assert(io.open("./test/expected/json/examples/example1.json"))
        local input = f1:read("a")
        local expected = require"test.expected.json.examples.output1"
        assert.same_ast(expected, parser:match(input))
        f1:close()
    end)

    test("generates a parser from Lua grammar", function()
        local f = assert(io.open("./test/expected/lua/grammar.peg", "r"))
        local src = f:read("a")
        local parser = generator.gen(src)
        f:close()

        -- Case 1:
        f = assert(io.open("./test/expected/lua/examples/example1.lua", "r"))
        local input = f:read("a")
        local expected = require"test.expected.lua.examples.output1"
        local ast, err, pos = parser:match(input)
        f:close()
        assert.same_ast(expected, ast)

        -- Other cases:
        local folder_name = [[./test/lua5.1-tests/]]
        for file_name in lfs.dir(folder_name) do
            f = assert(io.open(folder_name .. file_name, "r"))
            local input = f:read("a")
            local ast, err, pos = parser:match(input)
            if not ast then print(file_name, err, re.calcline(input, pos)) end
            assert.is.truthy(ast)
            f:close()
        end
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

        test("'Trying to use a not fragment lexical element in a lexical rule'", function()
            local src = [[
                s <- X X
                X <- LPAR 'x' RPAR
                LPAR <- '('
                RPAR <- ')'
            ]]
            local fn = function()
                generator.gen(src)
            end
            assert.has_error(fn, "Rule 2: Trying to use a not fragment lexical element in a lexical rule")
        end)

        test("'Trying to use a syntactic element in a lexical rule'", function ( )
            local src = [[
                S <- s
                s <- 'a' / 'b'
            ]]
            local fn = function()
                generator.gen(src)
            end
            assert.has_error(fn, "Rule 1: Trying to use a syntactic element in a lexical rule")
        end)
    end)

    context("generates a parser that reports when", function()
        test("lexical sequence tries to match syntactic sequence", function()
            local src = [[
                S <- '(' "b" ')'
            ]]
            local parser = generator.gen(src)
            assert.is.truthy(parser:match('(b)'))
            assert.is.truthy(parser:match('  (b)'))
            assert.is.falsy(parser:match('( b )'))
            assert.is.falsy(parser:match('(b)  '))
        end)

        test("use regular literal as keyword", function()
            local src = [[
                s <- (print / assign)+
                assign <- ID '=' INT
                INT <- %d+
                print <- "print" ID
            ]]
            local parser = generator.gen(src)

            local input = 'x = 10 print x printx = 20 print printx'
            assert.is.falsy(parser:match(input))
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
            local parser = generator.gen(src)

            local input = [[
                vector3 vector3D;
                vector3D.2;
            ]]
            assert.is.falsy(parser:match(input))
        end)
    end)
end)