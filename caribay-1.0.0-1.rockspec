package = "Caribay"
version = "1.0.0-1"
source = {
   url = "git://github.com/gustavoaca1997/Caribay",
   tag = "v1.0.0",
}
description = {
   summary = "A PEG parser generator",
   detailed = [[
       A PEG (Parsing Expression Grammar) Parser Generator built with LPeg(Label). The generated parser captures a generic AST (Abstract Syntactic Tree).
       Caribay makes easier to parse lexical symbols, comments, identifiers and keywords.
    ]],
   homepage = "http://...", -- We don't have one yet
   license = "MIT/X11" -- or whatever you like
}
dependencies = {
   "lua >= 5.1, < 5.4",
   "lpeglabel >= 1.6.0",
   "busted >= 2.0.0",
   -- If you depend on other rocks, add them here
}
build = {
   type = "builtin",
   modules = {
       ["caribay.parser"] = "src/parser.lua",
       ["caribay.generator"] = "src/generator.lua",
   }
}