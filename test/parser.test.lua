local function contains_error(state, arguments)
    local expectedMsg, toCall = table.unpack(arguments)

    local ok, errMsg = pcall(toCall, table.unpack(arguments, 3))
    if ok then
        return false
    else
        local pos = string.find( errMsg, expectedMsg )
        if pos then
            return true
        else
            error(errMsg)
        end
    end
end

assert:register("assertion", "contains_error", contains_error)

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
                            tag = 'literal',
                            captured = 'true',
                            'a'
                        }
                    }
                }
                assert.are.same(expected, ast)
            end)

            test("a literal", function()
                local ast = parser.match("s <- 'a'")
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'literal', 'a'
                        }
                    }
                }
                assert.are.same(expected, ast)
            end)

            test("a keyword", function()
                local ast = parser.match('s <- `a`')
                local expected = {
                    {
                        tag = 'rule',
                        {
                            tag = 'syn_sym', 's'
                        },
                        {
                            tag = 'keyword', 'a'
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
                            tag = 'literal', 'a'
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
                            { tag = 'literal', captured = 'true', 'a' },
                            { tag = 'literal', captured = 'true', 'b' },
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
                            tag = 'seq_exp',
                            {
                                tag = 'literal', 
                                captured = 'true',
                                'a'
                            },
                            {
                                tag = 'literal', 
                                captured = 'true',
                                'b'
                            }
                        }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)

            test("sequences and ordered choices", function()
                local input = 's <- "a" "b" / "c"'
                local expected = {
                    {
                        tag = 'rule',
                        { tag = 'syn_sym', 's' },
                        {
                            tag = 'ord_exp',
                            {
                                tag = 'seq_exp',
                                { tag = 'literal', captured = 'true', 'a' },
                                { tag = 'literal', captured = 'true', 'b' }
                            },
                            { tag = 'literal', captured = 'true', 'c'}
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
                            tag = 'star_exp',
                            { tag = 'literal', captured = 'true', 'a' }
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
                            tag = 'rep_exp',
                            { tag = 'syn_sym', 'bla' }
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
                            tag = 'opt_exp',
                            { tag = 'lex_sym', 'FOOD_TRUCK' }
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
                            tag = 'and_exp',
                            { tag = 'syn_sym', 'e1' }
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
                            tag = 'not_exp',
                            {  tag = 'lex_sym', 'EXP_1' }
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
                        { tag = 'class', '[aeiou12345_]' }
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
                        { tag = 'class', '%d' }
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
                        { tag = 'class', '[0-7_<>?!%ux-z]' }
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
                            tag = 'seq_exp',
                            { tag = 'any', '.' },
                            { tag = 'literal', captured = 'true', ', ' },
                            { tag = 'any', '.' }
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
                        { tag = 'syn_sym', 's' },
                        { tag = 'empty', '%e' }
                    }
                }
                assert.are.same(expected, parser.match(input))
            end)

            test("empty-character II", function()
                local input = "s <- %empty"
                local expected = {
                    {
                        tag = 'rule',
                        { tag = 'syn_sym', 's' },
                        { tag = 'empty', '%e' }
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
                        tag = 'seq_exp',
                        { tag = 'class', '%s' },
                        { tag = 'class', '%d' },
                        { tag = 'class', '%d' },
                        { tag = 'literal', captured = 'true', '/' },
                        { tag = 'class', '%u' },
                        { tag = 'class', '%u' },
                        { tag = 'literal', captured = 'true', '/' },
                        { tag = 'class', '%d' },
                        { tag = 'class', '%d' },
                        { tag = 'class', '%d' },
                        { tag = 'class', '%d' },
                        { tag = 'class', '%s' },
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
                        tag = 'seq_exp',
                        {
                            tag = 'literal', captured = 'true', 'a'
                        },
                        {
                            tag = 'star_exp',
                            {
                                tag = 'seq_exp',
                                {
                                    tag = 'literal', captured = 'true', ', '
                                },
                                {
                                    tag = 'syn_sym', 's'
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
                        tag = 'seq_exp',
                        { tag = 'literal', captured = 'true', 'a' },
                        { tag = 'syn_sym', 'as'}
                    }
                },
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 'as' },
                    {
                        tag = 'star_exp',
                        { tag = 'literal', captured = 'true', ', a'}
                    }
                }
            }
            local output = parser.match(input)
            assert.are.same(expected, output)
        end)

        test("fragment annotation", function()
            local input = [[
                NUMBER <- INT / HEX / FLOAT
                fragment INT <- %d+
                fragment FLOAT <- %d+ '.' %d+
                fragment HEX <- '0x' [0-9a-f]+
            ]]
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'lex_sym', 'NUMBER' },
                    {
                        tag = 'ord_exp',
                        { tag = 'lex_sym', 'INT' },
                        { tag = 'lex_sym', 'HEX' },
                        { tag = 'lex_sym', 'FLOAT' },
                    }
                },
                {
                    tag = 'rule',
                    fragment = 'true',
                    { tag = 'lex_sym', 'INT' },
                    {
                        tag = 'rep_exp',
                        { tag = 'class', '%d' }
                    }
                },
                {
                    tag = 'rule',
                    fragment = 'true',
                    { tag = 'lex_sym', 'FLOAT' },
                    {
                        tag = 'seq_exp',
                        {
                            tag = 'rep_exp',
                            { tag = 'class', '%d' },
                        },
                        { tag = 'literal', '.' },
                        {
                            tag = 'rep_exp',
                            { tag = 'class', '%d' },
                        },
                    }
                },
                {
                    tag = 'rule',
                    fragment = 'true',
                    { tag = 'lex_sym', 'HEX' },
                    {
                        tag = 'seq_exp',
                        { tag = 'literal', '0x' },
                        {
                            tag = 'rep_exp',
                            { tag = 'class', '[0-9a-f]' },
                        }
                    }
                }
            }
            assert.are.same(expected, parser.match(input))
        end)

        test("syntactic symbol with 'fragment' as preffix", function()
            local input = [[
                s <- fragment_moon*
                fragment_moon <- "(|"
            ]]
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 's' },
                    {
                        tag = 'star_exp',
                        { tag = 'syn_sym', 'fragment_moon' }
                    },
                },
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 'fragment_moon' },
                    {
                        tag = 'literal',
                        captured = 'true',
                        '(|'
                    }
                }
            }
            assert.are.same(expected, parser.match(input))
        end)

        test("keyword annotation", function()
            local input = [[
                type <- "number" / "string" / VECTOR
                @VECTOR <- "vector" ([1-9][0-9]*)?
            ]]
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 'type' },
                    {
                        tag = 'ord_exp',
                        { tag = 'literal', captured = 'true', 'number' },
                        { tag = 'literal', captured = 'true', 'string' },
                        { tag = 'lex_sym', 'VECTOR' },
                    }
                },
                {
                    tag = 'rule',
                    keyword = 'true',
                    { tag = 'lex_sym', 'VECTOR' },
                    {
                        tag = 'seq_exp',
                        { tag = 'literal', captured = 'true', 'vector' },
                        {
                            tag = 'opt_exp',
                            {
                                tag = 'seq_exp',
                                { tag = 'class', '[1-9]' },
                                {
                                    tag = 'star_exp',
                                    { tag = 'class', '[0-9]' },
                                }
                            }
                        }
                    }
                }
            }
            assert.are.same(expected, parser.match(input))
        end)

        test("keyword and fragment annotation", function()
            local input = [[
                type <- "number" / "string" / VECTOR
                fragment @VECTOR <- "vector" ([1-9][0-9]*)?
            ]]
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 'type' },
                    {
                        tag = 'ord_exp',
                        { tag = 'literal', captured = 'true', 'number' },
                        { tag = 'literal', captured = 'true', 'string' },
                        { tag = 'lex_sym', 'VECTOR' },
                    }
                },
                {
                    tag = 'rule',
                    fragment = 'true',
                    keyword = 'true',
                    { tag = 'lex_sym', 'VECTOR' },
                    {
                        tag = 'seq_exp',
                        { tag = 'literal', captured = 'true', 'vector' },
                        {
                            tag = 'opt_exp',
                            {
                                tag = 'seq_exp',
                                { tag = 'class', '[1-9]' },
                                {
                                    tag = 'star_exp',
                                    { tag = 'class', '[0-9]' },
                                }
                            }
                        }
                    }
                }
            }
            assert.are.same(expected, parser.match(input))
        end)

        test("a JSON grammar", function()
            local f = assert(io.open("./test/expected/json/grammar.peg", "r"))
            local input = f:read("a")

            local expected = require"test.expected.json.ast"

            assert.are.same(expected, parser.match(input))
        end)

        test("rule with semantic action", function()
            local input = [[
                s       <- pair (',' pair)*
                pair    <- { STRING ':' NUMBER, map_insert}
                STRING  <- [a-zA-Z0-9_]+
                NUMBER <- %d+ ('.' %d+)?
            ]]
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 's' },
                    {
                        tag = 'seq_exp',
                        { tag = 'syn_sym', 'pair' },
                        {
                            tag = 'star_exp',
                            {
                                tag = 'seq_exp',
                                { tag = 'literal', ',' },
                                { tag = 'syn_sym', 'pair' }
                            }
                        }
                    }
                },
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 'pair' },
                    {
                        tag = 'action',
                        action = 'map_insert',
                        {
                            tag = 'seq_exp',
                            { tag = 'lex_sym', 'STRING' },
                            { tag = 'literal', ':' },
                            { tag = 'lex_sym', 'NUMBER' },
                        },
                    }
                },
                {
                    tag = 'rule',
                    { tag = 'lex_sym', 'STRING' },
                    {
                        tag = 'rep_exp',
                        { tag = 'class', '[a-zA-Z0-9_]' }
                    }
                },
                {
                    tag = 'rule',
                    { tag = 'lex_sym', 'NUMBER' },
                    {
                        tag = 'seq_exp',
                        {
                            tag = 'rep_exp',
                            { tag = 'class', '%d' }
                        },
                        {
                            tag = 'opt_exp',
                            {
                                tag = 'seq_exp',
                                { tag = 'literal', '.' },
                                {
                                    tag = 'rep_exp',
                                    { tag = 'class', '%d' }
                                }
                            }
                        }
                    },
                }
            }
            assert.are.same(expected, parser.match(input))
        end)

        test("rule with nested semantic action", function()
            local input = [[
                s       <- pair (',' pair)*
                pair    <- { {STRING, parse_esc} ':' NUMBER, map_insert}
                STRING  <- [a-zA-Z0-9_]+
                NUMBER <- %d+ ('.' %d+)?
            ]]
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 's' },
                    {
                        tag = 'seq_exp',
                        { tag = 'syn_sym', 'pair' },
                        {
                            tag = 'star_exp',
                            {
                                tag = 'seq_exp',
                                { tag = 'literal', ',' },
                                { tag = 'syn_sym', 'pair' }
                            }
                        }
                    }
                },
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 'pair' },
                    {
                        tag = 'action',
                        action = 'map_insert',
                        {
                            tag = 'seq_exp',
                            { 
                                tag = 'action',
                                action = 'parse_esc',
                                { tag = 'lex_sym', 'STRING' },
                            },
                            { tag = 'literal', ':' },
                            { tag = 'lex_sym', 'NUMBER' },
                        },
                    }
                },
                {
                    tag = 'rule',
                    { tag = 'lex_sym', 'STRING' },
                    {
                        tag = 'rep_exp',
                        { tag = 'class', '[a-zA-Z0-9_]' }
                    }
                },
                {
                    tag = 'rule',
                    { tag = 'lex_sym', 'NUMBER' },
                    {
                        tag = 'seq_exp',
                        {
                            tag = 'rep_exp',
                            { tag = 'class', '%d' }
                        },
                        {
                            tag = 'opt_exp',
                            {
                                tag = 'seq_exp',
                                { tag = 'literal', '.' },
                                {
                                    tag = 'rep_exp',
                                    { tag = 'class', '%d' }
                                }
                            }
                        }
                    },
                }
            }
            assert.are.same(expected, parser.match(input))
        end)

        test("scaped quotes I", function()
            local input = 's <- "\\"" '
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 's' },
                    { tag = 'literal', captured = 'true', '"' }
                },
            }
            assert.are.same(expected, parser.match(input))
        end)
    
        test("scaped quotes II", function()
            local input = [[
                s <- "\"" a "\""
                a <- '\''*
            ]]
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 's' },
                    {
                        tag = 'seq_exp',
                        { tag = 'literal', captured = 'true', '"' },
                        { tag = 'syn_sym', 'a' },
                        { tag = 'literal', captured = 'true', '"' },
                    }
                },
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 'a' },
                    {
                        tag = 'star_exp',
                        { tag = 'literal', "'" }
                    }
                }
            }
            assert.are.same(expected, parser.match(input))
        end)

        test("scaped quotes II", function()
            local input = [[
                s <- "'literal'" `\"a\"` '"not captured"'
            ]]
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 's' },
                    {
                        tag = 'seq_exp',
                        { tag = 'literal', captured = 'true', "'literal'" },
                        { tag = 'keyword', '"a"' },
                        { tag = 'literal', '"not captured"' },
                    }
                },
            }
            assert.are.same(expected, parser.match(input))
        end)
    
        test("class with closing square bracket", function()
            local input = [=[
                s <- [^]]
            ]=]
            local expected = {
                {
                    tag = 'rule',
                    { tag = 'syn_sym', 's' },
                    { tag = 'class', '[^]]' }
                }
            }
            assert.are.same(expected, parser.match(input))
        end)
        
    end)

    context("throws", function()
        test("'Arrow expected' on bad written rule", function()
            local input = [[
                s <- a ";"?
                a "break"
            ]]
            assert.contains_error("Arrow expected", parser.match, input)
        end)

        test("'Lexical identifier expected' on bad written fragment annotation I", function()
            local input = [[
                type <- "number" / "string" / VECTOR
                fragment vector <- "vector" ([1-9][0-9]*)?
            ]]
            assert.contains_error("Lexical identifier expected", parser.match, input)
        end)

        test("'Lexical identifier expected' on bad written fragment annotation II", function()
            local input = [[
                type <- "number" / "string" / VECTOR
                fragment @vector <- "vector" ([1-9][0-9]*)?
            ]]
            assert.contains_error("Lexical identifier expected", parser.match, input)
        end)

        test("'Valid expression expected' on bad written rule", function()
            local input = [[
                s <- a b?
                a <-
                b <- ";"
            ]]
            assert.contains_error("Valid expression expected", parser.match, input)
        end)

        test("'Missing end of rule' on bad written rule I", function()
            local input = [[
                s <- a b? ~
                a <- "break"
                b <- ";"
            ]]
            assert.contains_error("Missing end of rule", parser.match, input)
        end)

        test("'Missing end of rule' on bad written rule II", function()
            local input = [[
                s <- a b? a <- "break"
                b <- ";"
            ]]
            assert.contains_error("Missing end of rule", parser.match, input)
        end)

        test("'Valid expression expected' on bad written action I", function()
            local input = 's <- { , func}'
            assert.contains_error("Valid expression expected", parser.match, input)
        end)

        test("'Valid expression expected' on bad written action II", function()
            local input = 's <- {  }'
            assert.contains_error("Valid expression expected", parser.match, input)
        end)

        test("'Valid expression expected' on bad written action III", function()
            local input = 's <- {  '
            assert.contains_error("Valid expression expected", parser.match, input)
        end)

        test("'Valid expression expected' on bad written action IV", function()
            local input = 's <- { { , gunc }, func }'
            assert.contains_error("Valid expression expected", parser.match, input)
        end)

        test("'Missing comma' on bad written action", function()
            local input = 's <- { "bla" func }'
            assert.contains_error("Missing comma", parser.match, input)
        end)

        test("'Valid identifier expected' on bad written action I", function()
            local input = 's<-{"bla",}'
            assert.contains_error("Valid identifier expected", parser.match, input)
        end)

        test("'Valid identifier expected' on bad written action II", function()
            local input = [[
                s <- {a , 
                a <- "bla"
            ]]
            assert.contains_error("Valid identifier expected", parser.match, input)
        end)

        test("'Closing bracket expected' on bad written action I", function()
            local input = 's <- { "bla", func'
            assert.contains_error("Closing bracket expected", parser.match, input)
        end)

        test("'Closing bracket expected' on bad written action II", function()
            local input = 's <- { "bla", a b c d'
            assert.contains_error("Closing bracket expected", parser.match, input)
        end)

        test("'Valid choice expected' on bad written ordered choice I", function()
            local input = [[
                a <- 'a'
                b <- 'b'
                d <- 'd'
                s <- a b / / d
            ]]
            assert.contains_error("Valid choice expected", parser.match, input)
        end)

        test("'Valid choice expected' on bad written ordered choice II", function()
            local input = [[
                s <- a b / d /
                a <- 'a'
                b <- 'b'
                d <- 'd'
            ]]
            assert.contains_error("Valid choice expected", parser.match, input)
        end)

        test("invalid atom on bad written predicate expression I", function()
            local input = [[
                s <- a (! / &c)
                a <- 'a'
                b <- 'b'
                c <- 'c'
            ]]
            assert.contains_error("Valid expression after predicate operator expected", parser.match, input)
        end)

        test("invalid atom on bad written predicate expression II", function()
            local input = [[
                s <- a (!b / &)
                a <- 'a'
                b <- 'b'
                c <- 'c'
            ]]
            assert.contains_error("Valid expression after predicate operator expected", parser.match, input)
        end)

        test("invalid atom on bad written predicate expression I", function()
            local input = [[
                s <- a (!~ / &c)
                a <- 'a'
                b <- 'b'
                c <- 'c'
            ]]
            assert.contains_error("Valid expression after predicate operator expected", parser.match, input)
        end)

        test("'Closing parentheses expected' on bad written expression I", function()
            local input = [[
                s <- (s ("0" / "1" / %e)
            ]]
            assert.contains_error("Closing parentheses expected", parser.match, input)
        end)

        test("'Closing parentheses expected' on bad written expression II", function()
            local input = [[
                s <- (s ("0" / "1" / %e
            ]]
            assert.contains_error("Closing parentheses expected", parser.match, input)
        end)

        test("'Closing double quotes expected' on bad written literal I", function()
            local input = 's <- "bla '
            assert.contains_error("Closing double quotes expected", parser.match, input)
        end)

        test("'Closing double quotes expected' on bad written literal II", function()
            local input = [[
                s <- "bla \"
            ]]
            assert.contains_error("Closing double quotes expected", parser.match, input)
        end)

        test("'Closing single quotes expected' on bad written literal I", function()
            local input = "s <- 'bla "
            assert.contains_error("Closing single quotes expected", parser.match, input)
        end)

        test("'Closing single quotes expected' on bad written literal II", function()
            local input = [[
                s <- 'bla \'
            ]]
            assert.contains_error("Closing single quotes expected", parser.match, input)
        end)

        test("'Closing backstick expected' on bad written keyword", function()
            local input = [[
                s <- a `null
                a <- "="
            ]]
            assert.contains_error("Closing backstick expected", parser.match, input)
        end)

        test("'Closing square bracket expected' on bad written character class I", function()
            local input = 's <- "foo" [^"'
            assert.contains_error("Closing square bracket expected", parser.match, input)
        end)

        test("'Closing square bracket expected' on bad written character class II", function()
            local input = 's <- "foo" [^]"'
            assert.contains_error("Closing square bracket expected", parser.match, input)
        end)

        test("'Right bound of range expected' on bad written range character class I", function()
            local input = 's <- [xyz0-]'
            assert.contains_error("Right bound of range expected", parser.match, input)
        end)

        test("'Right bound of range expected' on bad written range character class II", function()
            local input = 's <- [xyz0-'
            assert.contains_error("Right bound of range expected", parser.match, input)
        end)

        -- pending("'Missing annotation' on bad written annotation", function()

        -- end)
    end)
end)