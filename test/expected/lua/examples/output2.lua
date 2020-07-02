return {
    tag = 'program',
    {
        tag = 'chunk',
        {
            tag = 'stat',
            {
                tag = 'varlist',
                {
                    tag = 'var',
                    { tag = 'ID', 'x' },
                },
            },
            {
                tag = 'explist',
                {
                    tag = 'exp',
                    {
                        tag = 'arit',
                        { tag = 'NUMBER', '4' },
                        { tag = 'TERM_OP', '+' },
                        {
                            tag = 'term',
                            { tag = 'ID', 'x' },
                            { tag = 'FACTOR_OP', '/' },
                            { tag = 'NUMBER', '2' }
                        }
                    }
                }
            }
        },
    },
}