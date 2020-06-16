local assertions = require"test.assertions"
assert:register("assertion", "contains_error", assertions.contains_error)

local function assert_output(src, input, expected)
    local parser = generator.gen(src)
    assert.are.same(expected, parser:match(input))
end

context("generator", function()
    setup(function()
        generator = require"src.generator"
    end)

    context("generates a parser from a grammar with", function()
        context("a trivial rule with", function()
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

            test("a not captured literal between two captured literals", function()
                local src = [[
                    s <- "{" 'x' "}"
                ]]

                local expected = {
                    tag = 's',
                    { tag = 'token', '{' },
                    { tag = 'token', '}' },
                }
                assert_output(src, '{x}', expected)
            end)
        end)
    end)
end)