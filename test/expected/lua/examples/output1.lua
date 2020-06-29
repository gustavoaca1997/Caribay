return {
    tag = 'chunk',
    {
        tag = 'stat',
        {
            tag = 'varlist',
            {
                tag = 'var',
                { tag = 'ID', '_x_10' },
            },
        },
        {
            tag = 'explist',
            {
                tag = 'exp',
                { tag = 'NUMBER', '10' },
            }
        }
    },
    {
        tag = 'laststat',
        { tag = 'token', 'return' },
        {
            tag = 'explist',
            {
                tag = 'exp',
                {
                    tag = 'prefiexp',
                    { tag = 'ID', '_x_10' },
                }
            }
        }
    }
}