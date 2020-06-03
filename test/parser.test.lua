context("Parser", function ( )
    local parser

    setup(function()
        parser = require"src.parser"
    end)

    context("matches", function()
        context("a single trivial rule with", function()
            test("a literal", function()
                local ast = parser.match('s <- "a"')
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'literal', 'a'
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, ast)
            end)

            test("spaces at the beginning", function()
                local input = "    s <- 'a'"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'literal', 'a'
                                }
                            }
                        }
                    }
                }
                local output, p, n = parser.match(input)
                assert.are.same(expected, output)
            end)
    
            test("an ordered choice", function() 
                local input = 's <- "a" / "b"'
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'literal', 'a'
                                }
                            },
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'literal', 'b'
                                }
                            }
                        }
                    }
                }
                local output, p, n = parser.match(input)
                assert.are.same(expected, output)
            end)
    
            test("a sequence", function() 
                local input = 's <- "a" "b"'
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'literal', 'a'
                                },
                                {
                                    tag = 'literal', 'b'
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)
    
            test("Kleen star", function()
                local input = 's <- "a"*'
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'star_exp',
                                    {
                                        tag = 'literal', 'a'
                                    }
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)
    
            test("repetition", function()
                local input = 's <- bla+'
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'rep_exp',
                                    {
                                        tag = 'syn_sym', 'bla'
                                    }
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)
    
            test("optional", function()
                local input = 's <- FOOD_TRUCK?'
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'opt_exp',
                                    {
                                        tag = 'lex_sym', 'FOOD_TRUCK'
                                    }
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)
    
            test("and-predicate", function()
                local input = "s <- &e1"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'and_exp',
                                    {
                                        tag = 'syn_sym', 'e1'
                                    }
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)
    
            test("not-predicate", function() 
                local input = "s <- !EXP_1"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'not_exp',
                                    {
                                        tag = 'lex_sym', 'EXP_1'
                                    }
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)
    
            test("simple character class", function() 
                local input = "s <- [aeiou12345_]"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'class', '[aeiou12345_]'
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)

            test("simple predefined character class", function() 
                local input = "s <- %d"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'class', '%d'
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)
    
            test("complex character class", function() 
                local input = "s <- [0-7_<>?!%ux-z]"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'class', '[0-7_<>?!%ux-z]'
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)

            test("any-character", function()
                local input = 's <- . ", " .'
                local expected = {
                    {
                        tag = 'rule',
                        { tag = 'syn_sym', 's' },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                { tag = 'any', '.' },
                                { tag = 'literal', ', ' },
                                { tag = 'any', '.' }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)

            test("empty-character I", function()
                local input = "s <- %e"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'empty', '%e'
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)

            test("empty-character II", function()
                local input = "s <- %empty"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'empty', '%e'
                                }
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)
        end)

        test("a single rule with predefined character classes", function() 
            local input = 's <- %s %d %d "/" %u %u "/" %d %d %d %d %s'
            local expected = {
                {
                    tag = 'rule',
                    {
                        tag = 'syn_sym', 's'
                    },
                    {
                        tag = 'ord_exp',
                        {
                            tag = 'seq_exp',
                            { tag = 'class', '%s' },
                            { tag = 'class', '%d' },
                            { tag = 'class', '%d' },
                            { tag = 'literal', '/' },
                            { tag = 'class', '%u' },
                            { tag = 'class', '%u' },
                            { tag = 'literal', '/' },
                            { tag = 'class', '%d' },
                            { tag = 'class', '%d' },
                            { tag = 'class', '%d' },
                            { tag = 'class', '%d' },
                            { tag = 'class', '%s' },
                        }
                    }
                }
            }
            assert.are.same(expected, parser.match(input))
        end)
    
        test("a recursive rule with Kleen star", function()
            local ast = parser.match('s <- "a" (", " s)*')
    
            local expected = {
                {
                    tag = 'rule',
                    { 
                        tag = 'syn_sym', 's' 
                    },
                    { 
                        tag = 'ord_exp',
                        {
                            tag = 'seq_exp',
                            {
                                tag = 'literal', 'a'
                            },
                            {
                                tag = 'star_exp',
                                {
                                    tag = 'ord_exp',
                                    {
                                        tag = 'seq_exp',
                                        {
                                            tag = 'literal', ', '
                                        },
                                        {
                                            tag = 'syn_sym', 's'
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            assert.are.same(expected, ast)
        end)

        test("two rules", function()
            local input = [[
                s <- "a" as
                as <- ", a"*
            ]]
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 's' },
                    {
                        tag = 'ord_exp',
                        {
                            tag = 'seq_exp',
                            { tag = 'literal', 'a' },
                            { tag = 'syn_sym', 'as'}
                        }
                    }
                },
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 'as' },
                    {
                        tag = 'ord_exp',
                        {
                            tag = 'seq_exp',
                            {
                                tag = 'star_exp',
                                { tag = 'literal', ', a'}
                            }
                        }
                    }
                }
            }
            local output = parser.match(input)
            assert.are.same(expected, output)
        end)

        test("a JSON grammar", function()
            local f = assert(io.open("./test/expected/json/grammar.peg", "r"))
            local input = f:read("a")

            local expected = require"test.expected.json.ast"

            assert.are.same(expected, parser.match(input))
        end)
        
    end)
end)