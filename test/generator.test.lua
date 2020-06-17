local assertions = require"test.assertions"
assert:register("assertion", "contains_error", assertions.contains_error)

local function assert_output(src, input, expected)
    local parser = generator.gen(src)
    local output, err, pos = parser:match(input)
    if output then
        assert.are.same(expected, output)
    else
        error(err .. ': ' .. pos)
    end
end

context("Generator", function()
    setup(function()
        generator = require"src.generator"
    end)

    context("throws", function()
        test("'Not defined' I", function()
            local src = [[
                s <- skip "a" (star / '+')
            ]]
            local fn = function()
                generator.gen(src)
            end
            assert.has_error(fn, "rule 'star' undefined in given grammar")
        end)
    end)

    context("generates a parser that report when", function()
        pending("lexical sequence tries to match syntactic sequence", function()

        end)
    end)

    context("generates a parser from a grammar with", function()
        context("a rule with", function()
            test("a captured literal", function()
                local src = 's <- "a"'
                local expected = {
                    tag = 's',
                    { tag = 'token', 'a' }
                }
                assert_output(src, 'a', expected)
            end)

            test("a not captured literal", function()
                assert_output(
                    "s <- 'a'",
                    'a',
                    { tag = 's' }
                )
            end)

            test("a captured literal between two not captured literals", function()
                local src = [[
                    s <- '->' "a" '<-'
                ]]
                local expected = {
                    tag = 's',
                    { tag = 'token', 'a' }
                }
                assert_output(src, '->a<-', expected)
            end)

            test("a not captured literal between two captured literals I", function()
                local src = [[
                    s <- "{" 'x' "}"
                ]]

                local expected = {
                    tag = 's',
                    { tag = 'token', '{' },
                    { tag = 'token', '}' },
                }
                assert_output(src, '{x}', expected)
                assert_output(src, '{x }', expected)
                assert_output(src, '{   x } ', expected)
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

            test("usage of skip symbol", function()
                local src = [[
                    s <- skip ("a" '!' / '{' "b" '}' / '&' "c")
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
        end)
    end)
end)