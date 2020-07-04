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
                        { tag = 'term_op', { tag = 'token', '+' } },
                        {
                            tag = 'term',
                            { tag = 'ID', 'x' },
                            { tag = 'factor_op', { tag = 'token', '/' } },
                            { tag = 'NUMBER', '2' }
                        }
                    }
                }
            }
        },
    },
}