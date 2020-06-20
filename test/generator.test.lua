local assertions = require"test.assertions"
assert:register("assertion", "contains_error", assertions.contains_error)

context("Generator", function()
    setup(function()
        generator = require"src.generator"
    end)

    context("generates a parser that report when", function()
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

        pending("some fragments", function()
            local src = [[
                list <- NUMBER+
                NUMBER <- INT / FLOAT
                fragment INT <- %d+
                fragment FLOAT <- %d+ '.' %d+
            ]]
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
                rand_bits <- BITS
                BITS <- BIT+
                fragment BIT <- '0' / '1'
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
end)