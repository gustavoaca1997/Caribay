describe("Parser", function ( )
    local parser

    setup(function()
        parser = require"src.parser"
    end)

    context("matches", function()
        context("a single trivial rule with", function()
            it("a single trivial rule with a literal", function()
                ast = parser.match('S <- "a"')
                expected = {
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
    
            pending("an ordered choice", function() end)
    
            pending("a sequence", function() end)
    
            pending("Kleen star", function() end)
    
            pending("repetition", function() end)
    
            pending("optional", function() end)
    
            pending("and-predicate", function() end)
    
            pending("not-predicate", function() end)
    
            pending("simple character class", function() end)
    
            pending("complex character class", function() end)
    
            pending("defined character class", function() end)
        end)
    
        it("a recursive rule with Kleen star", function()
            ast = parser.match('S <- "a" (", " S)*')
    
            expected = {
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