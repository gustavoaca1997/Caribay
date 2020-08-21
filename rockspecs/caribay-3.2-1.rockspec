package = "Caribay"
version = "3.2-1"
source = {
   url = "git://github.com/gustavoaca1997/Caribay",
   tag = "v3.2",
}
description = {
   summary = "A PEG parser generator",
   detailed = [[
       A PEG (Parsing Expression Grammar) Parser Generator built with LPeg(Label). The generated parser captures a generic AST (Abstract Syntactic Tree).
       Caribay makes easier to parse lexical symbols, comments, identifiers and keywords.
    ]],
   license = "MIT",
   homepage = "https://github.com/gustavoaca1997/Caribay",
}
dependencies = {
   "lua >= 5.1, < 5.4",
   "lpeglabel >= 1.6.0",
   "busted >= 2.0.0",
}
build = {
   type = "builtin",
   modules = {
       ["caribay.parser"] = "src/parser.lua",
       ["caribay.generator"] = "src/generator.lua",
       ["caribay.annotator"] = "src/annotator.lua",
       ["caribay.Set"] = "src/Set.lua",
       ["caribay.Symbol"] = "src/Symbol.lua",
   }
}