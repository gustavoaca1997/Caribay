describe("Parser", function ( )
    local parser

    setup(function()
        parser = require"src.parser"
    end)

    context("matches", function()
        context("a single trivial rule with", function()
            it("a literal", function()
                local ast = parser.match('S <- "a"')
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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
    
            it("an ordered choice", function() 
                local input = 'S <- "a" / "b"'
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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
                assert.are.same(expected, parser.match(input))
            end)
    
            it("a sequence", function() 
                local input = 'S <- "a" "b"'
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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
    
            it("Kleen star", function()
                local input = 'S <- "a"*'
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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
    
            it("repetition", function()
                local input = 'S <- bla+'
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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
    
            it("optional", function()
                local input = 'S <- FOOD_TRUCK?'
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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
    
            it("and-predicate", function()
                local input = "S <- &e1"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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
    
            it("not-predicate", function() 
                local input = "S <- !EXP_1"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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
    
            it("simple character class", function() 
                local input = "S <- [aeiou12345_]"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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

            it("simple predefined character class", function() 
                local input = "S <- %d"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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
    
            it("complex character class", function() 
                local input = "S <- [0-7_<>?!%ux-z]"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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

            it("any-character", function()
                local input = 'S <- . ", " .'
                local expected = {
                    {
                        tag = 'rule',
                        { tag = 'lex_sym', 'S' },
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

            it("empty-character I", function()
                local input = "S <- %e"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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

            it("empty-character II", function()
                local input = "S <- %empty"
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'lex_sym', 'S'
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

        it("a single rule with predefined character classes", function() 
            local input = 'S <- %s %d %d "/" %u %u "/" %d %d %d %d %s'
            local expected = {
                {
                    tag = 'rule',
                    {
                        tag = 'lex_sym', 'S'
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
    
        it("a recursive rule with Kleen star", function()
            local ast = parser.match('S <- "a" (", " S)*')
    
            local expected = {
                {
                    tag = 'rule',
                    { 
                        tag = 'lex_sym', 'S' 
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
                                            tag = 'lex_sym', 'S'
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

        pending("multiple rules", function() end)
        
    end)
end)