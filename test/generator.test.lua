local assertions = require"test.assertions"
assert:register("assertion", "contains_error", assertions.contains_error)

context("Generator", function()
    setup(function()
        generator = require"src.generator"
    end)

    context("generates a parser from a grammar with", function()
        context("a rule with", function()
            test("a captured literal", function()
                local src = 's <- "a"'
                local parser = generator.gen(src)
                local expected = {
                    tag = 's',
                    { tag = 'token', 'a' }
                }
                assert.are.same(expected, parser:match('a'))
                assert.is.falsy(parser:match('aa'))
                assert.is.falsy(parser:match('aa'))
                assert.is.falsy(parser:match('b'))
            end)

            test("a not captured literal", function()
                local parser = generator.gen("s <- 'a'")
                assert.are.same({ tag = 's' }, parser:match('a'))
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
                    tag = 's',
                    { tag = 'token', 'a' }
                }
                assert.are.same(expected, parser:match('->a<-'))
                assert.are.same(expected, parser:match('->  a<- '))
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
                    tag = 's',
                    { tag = 'token', '{' },
                    { tag = 'token', '}' },
                }
                assert.are.same(expected, parser:match('{x}'))
                assert.are.same(expected, parser:match('{x }'))
                assert.are.same(expected, parser:match('{  x} '))
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
                assert.are.same(expected, parser:match'a')

                expected[1][1] = 'b'
                assert.are.same(expected, parser:match'b')

                expected[1][1] = 'c'
                assert.are.same(expected, parser:match'c')
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
                assert.are.same(expected, parser:match('a!'))
                assert.are.same(expected, parser:match('a  !'))

                expected[1][1] = 'b'
                assert.are.same(expected, parser:match('{ b }'))
                assert.are.same(expected, parser:match('{   b }'))

                expected[1][1] = 'c'
                assert.are.same(expected, parser:match('&c'))
                assert.are.same(expected, parser:match('&   c  '))
            end)

            test("usage of initial automatic skip", function()
                local src = [[
                    s <- "a" '!' / '{' "b" '}' / '&' "c"
                ]]
                local parser = generator.gen(src)
                local expected = {
                    tag = 's',
                    { tag = 'token', 'a' }
                }
                assert.are.same(expected, parser:match(' a!'))
                assert.are.same(expected, parser:match('     a  !'))

                expected[1][1] = 'b'
                assert.are.same(expected, parser:match(' { b }'))
                assert.are.same(expected, parser:match('    {   b }'))

                expected[1][1] = 'c'
                assert.are.same(expected, parser:match(' &c'))
                assert.are.same(expected, parser:match('   &   c  '))
            end)

            test("a recursive syntactic rule", function()
                local src = [[
                    s <- '{' s '}' / "x"
                ]]
                local parser = generator.gen(src)
                
                local expected = {
                    tag = 's',
                    {
                        tag = 's',
                        {
                            tag = 's',
                            {
                                tag = 's',
                                { tag = 'token', 'x' }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser:match('  {{  {   x } }   }'))
                assert.are.same({ tag = 's', { tag = 'token', 'x' } }, parser:match('x'))

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
            assert.are.same(expected, parser:match('{b}'))
            assert.are.same(expected, parser:match('  {     b } '))

            expected = {
                tag = 's',
                {
                    tag = 'between_parentheses',
                    { tag = 'token', 'p' },
                }
            }
            assert.are.same(expected, parser:match('(p)'))
            assert.are.same(expected, parser:match('( p)   '))

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
            assert.are.same(expected, parser:match('GustavoCastellanos'))
            assert.are.same(expected, parser:match('Gustavo Castellanos'))
            assert.are.same(expected, parser:match('   Gustavo    Castellanos'))
            assert.is.falsy(parser:match('GustavoC astellanos'))
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
                tag = 'list',
                {
                    tag = 'NUMBER',
                    '123'
                },{
                    tag = 'NUMBER',
                    '123123123.3'
                },{
                    tag = 'NUMBER',
                    '12'
                },{
                    tag = 'NUMBER',
                    '1.23'
                },
            }
            assert.are.same(expected, parser:match("123 123123123.3 12 1.23"))
            assert.are.same(expected, parser:match(" 123   123123123.3   12  1.23   "))
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
            assert.are.same(expected, parser:match('00101'))
            assert.are.same(expected, parser:match('  00 1         0 1    '))
            assert.are.same(expected, parser:match(' 0   0 10         1'))
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
            assert.are.same(expected, parser:match('00101'))
            assert.are.same(expected, parser:match('   00101 '))
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
            assert.are.same(expected, parser:match(input))
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
            assert.are.same(expected, parser:match(input))
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
            assert.are.same(expected, parser:match(input))
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
            assert.are.same(expected, parser:match(input))
        end)

        test("keyword rules and its own skip rule", function()
            local src = [[
                s <- (init / idx)+
                init <- VECTOR ID
                idx <- ID '.' INT

                @VECTOR <- 'vector' [1-9]
                INT <- %d+

                skip <- (' ' / '\n')*
            ]]
            local parser = generator.gen(src)

            local input = [[
                vector3 vector3D
                vector3D.2
            ]]
            local expected = {
                tag = 's',
                {
                    tag = 'init',
                    { tag = 'VECTOR', 'vector3' },
                    { tag = 'ID', 'vector3D' },
                },
                {
                    tag = 'idx',
                    { tag = 'ID', 'vector3D' },
                    { tag = 'INT', '2' },
                },
            }
            assert.are.same(expected, parser:match(input))
        end)

        test("fragment keyword and its own skip rule", function()
            local src = [[
                s <- (init / idx)+
                init <- TYPE ID
                idx <- ID '.' INT

                TYPE <- `map` / VECTOR
                fragment @VECTOR <- 'vector' [1-9]
                INT <- %d+

                skip <- (' ' / '\n')*
            ]]
            local parser = generator.gen(src)

            local input = [[
                map map_0
                map_0.5

                vector3 vector3D
                vector3D.2
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
            assert.are.same(expected, parser:match(input))
        end)

    end)

    test("generates a parser from JSON grammar", function()
        local f = assert(io.open("./test/expected/json/grammar.peg", "r"))
        local src = f:read("a")
        local parser = generator.gen(src)

        -- Case 1:
        local f1 = assert(io.open("./test/expected/json/examples/example1.json"))
        local input = f1:read("a")
        local expected = require"test.expected.json.examples.example1"
        assert.are.same(expected, parser:match(input))
    end)

    context("throws", function()
        test("'Not defined'", function()
            local src = [[
                s <- skip "a" (star / '+')
            ]]
            local fn = function()
                generator.gen(src)
            end
            assert.has_error(fn, "rule 'star' undefined in given grammar")
        end)

        test("'Trying to use a fragment in a syntactic rule'", function()
            local src = [[
                s <- x x
                fragment LPAR <- '('
                fragment RPAR <- ')'
                x <- LPAR "x" RPAR
            ]]
            local fn = function()
                generator.gen(src)
            end
            assert.has_error(fn, "Rule 4: Trying to use a fragment in a syntactic rule")
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

                skip <- (' ' / '\n')*
            ]]
            local parser = generator.gen(src)

            local input = [[
                vector3 vector3D
                vector3D.2
            ]]
            assert.is.falsy(parser:match(input))
        end)
    end)
end)