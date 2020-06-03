return {
    {
        tag = 'rule',
        { tag = 'syn_sym', 'json' },
        {
            tag = 'ord_exp',
            { tag = 'seq_exp', { tag = 'syn_sym', 'value' } }
        },
    },
    {
        tag = 'rule',
        { tag = 'syn_sym', 'value' },
        {
            tag = 'ord_exp',
            { tag = 'seq_exp', { tag = 'syn_sym', 'object' } },
            { tag = 'seq_exp', { tag = 'syn_sym', 'array' } },
            { tag = 'seq_exp', { tag = 'lex_sym', 'BOOLEAN' } },
            { tag = 'seq_exp', { tag = 'lex_sym', 'STRING' } },
            { tag = 'seq_exp', { tag = 'lex_sym', 'NUMBER' } },
            { tag = 'seq_exp', { tag = 'literal', 'null' } },
        }
    },
    {
        tag = 'rule',
        { tag = 'lex_sym', 'NUMBER' },
        {
            tag = 'ord_exp',
            {
                tag = 'seq_exp',
                {
                    tag = 'rep_exp',
                    { tag = 'class', '%d' }
                },
                {
                    tag = 'opt_exp',
                    {
                        tag = 'ord_exp',
                        {
                            tag = 'seq_exp',
                            { tag = 'literal', '.' },
                            {
                                tag = 'rep_exp',
                                { tag = 'class', '%d' }
                            }
                        }
                    }
                }
            }
        }
    },
    {
        tag = 'rule',
        { tag = 'lex_sym', 'STRING' },
        {
            tag = 'ord_exp',
            {
                tag = 'seq_exp',
                { tag = 'literal', '"' },
                { tag = 'class', '[^"]' },
                { tag = 'literal', '"' },
            },
        }
    },
    {
        tag = 'rule',
        { tag = 'lex_sym', 'BOOLEAN' },
        {
            tag = 'ord_exp',
            {
                tag = 'seq_exp',
                { tag = 'literal', 'true' },
            },
            {
                tag = 'seq_exp',
                { tag = 'literal', 'false' },
            }
        },
    },
    {
        tag = 'rule',
        { tag = 'syn_sym', 'array' },
        {
            tag = 'ord_exp',
            {
                tag = 'seq_exp',
                { tag = 'literal', '['},
                {
                    tag = 'opt_exp',
                    {
                        tag = 'ord_exp',
                        {
                            tag = 'seq_exp',
                            { tag = 'syn_sym', 'value'},
                            {
                                tag = 'star_exp',
                                {
                                    tag = 'ord_exp',
                                    {
                                        tag = 'seq_exp',
                                        { tag = 'literal', ','},
                                        { tag = 'syn_sym', 'value'}
                                    }
                                }
                            }
                        }
                    }
                },
                { tag = 'literal', ']'},
            }
        }
    },
    {
        tag = 'rule',
        { tag = 'syn_sym', 'object' },
        {
            tag = 'ord_exp',
            {
                tag = 'seq_exp',
                { tag = 'literal', '{'},
                {
                    tag = 'opt_exp',
                    {
                        tag = 'ord_exp',
                        {
                            tag = 'seq_exp',
                            { tag = 'syn_sym', 'pair'},
                            {
                                tag = 'star_exp',
                                {
                                    tag = 'ord_exp',
                                    {
                                        tag = 'seq_exp',
                                        { tag = 'literal', ','},
                                        { tag = 'syn_sym', 'pair'}
                                    }
                                }
                            }
                        }
                    }
                },
                { tag = 'literal', '}'},
            }
        }
    },
    {
        tag = 'rule',
        { tag = 'syn_sym', 'pair' },
        {
            tag = 'ord_exp',
            {
                tag = 'seq_exp',
                { tag = 'syn_sym', 'string' },
                { tag = 'literal', ':' },
                { tag = 'syn_sym', 'value' }
            }
        }
    }
}