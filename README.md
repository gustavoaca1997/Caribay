# Caribay
A PEG (Parsing Expression Grammar) Parser Generator built with LPeg(Label). The generated parser captures a generic AST (Abstract Syntactic Tree).

Caribay makes easier to parse lexical symbols, comments, identifiers and keywords.

## Installation
You can install Caribay using [Luarocks](https://luarocks.org/):
```bash
luarocks install caribay
```

## Usage
You need to _require_ the module _src.generator_:
```lua
local generator = require"caribay.generator"
```
then you call the `gen` function passing a PEG as argument to generate an LPegLabel parser, which has a method `match` for matching:
```lua
local src = [[
    assign <- ID '=' number
    fragment number <- FLOAT / INT
    INT <- %d+
    FLOAT <- %d+ '.' %d+
]]
local parser = generator.gen(src)
parser:match[[     a_2     =   3.1416 ]]
```

## Syntax and examples
_You should first get familiar about PEGs [here](https://en.wikipedia.org/wiki/Parsing_expression_grammar)._

### Lexical and Syntactic symbols
Caribay differentiates lexical symbols from syntactic symbols as _UPPER_CASE_ symbols and _snake_case_ symbols, respectively. The difference is that **lexical symbols** capture all (and only) the pattern they match as a new AST node, while a **syntactic symbol** captures a new AST node but with an array with all the children nodes. See next examples to better understand.

### Character classes
Caribay supports character classes supported by the _re(label) module_. To match a string of alphanumeric characters you write something like this:
```peg
ALPHA_NUM <- [0-9a-zA-Z]+
```
And to capture each alphanumeric character, you use a syntactic symbol:
```peg
alpha_num <- [0-9a-zA-Z]+
```

The first parser captures the following AST when matching _8aBC3_:
```lua
{ tag = 'ALPHA_NUM', pos = 1, '8aBC3' }
```
The second parser captures the following AST matching same input:
```lua
{ tag = 'alpha_num', pos = 1, '8', 'a', 'B', 'C', '3' }
```

### Predefined rules
Caribay serves some useful predefined rules, which are overwritten if the user defines them:

#### SKIP
It is used to skip a pattern between lexical symbols. By default it is defined as follows:
```peg
SKIP <- ' '*
```
If the user defines a `COMMENT` rule, `SKIP` is defined as follows:
```peg
SKIP <- (' ' / COMMENT)*
```

#### ID
The _ID_ rule is defined by default by this PEG:
```peg
ID          <- ID_START ID_END?
ID_START    <- [a-zA-Z]
ID_END      <- [a-zA-Z0-9_]+
```
User can define their own `ID_START` and `ID_END` rules.

### Literals
#### Regular literals
To match a single literal the user writes the following grammar:
```peg
s <- 'this is a literal'
```

#### Captured literals
To also **capture** the literal in a syntactic rule, the user writes it with double quotes:
```peg
s <- "a"
```
The AST captured when matching _`a`_ is:
```lua
{ tag = 's', 'a' }
```
The user could also use a lexical symbol:
```peg
S <- 'a'
```
or
```peg
S <- "a"
```
With lexical symbols doesn't matter if the user uses single or double quotes.

#### Keywords
Keywords, which are surrounded by backsticks, are a special type of literals: Caribay captures them (when used on syntactic rules) and wraps them around code that ensures they are not confused with identifiers. Basically when matching a keyword _kw_, Caribay in reality matches:
```peg
`kw`!ID_END
```
and when matching an identifier, Caribay checks that it is not a keyword defined in the grammar. Here goes an example:
```peg
s <- (print / assign)+
assign <- ID '=' INT
INT <- %d+
print <- `print` ID
```
Caribay considers the first rule as the starting rule. The parser generated captures the following AST when matching _`x = 10 print x printx = 20 print printx`_:
```lua
{
    tag = 's',
    {
        tag = 'assign',
        { tag = 'ID', 'x' },
        { tag = 'INT', '10' },
    },
    {
        tag = 'print',
        { tag = 'token', 'print' },
        { tag = 'ID', 'x' },
    },
    {
        tag = 'assign',
        { tag = 'ID', 'printx' },
        { tag = 'INT', '20' },
    },
    {
        tag = 'print',
        { tag = 'token', 'print' },
        { tag = 'ID', 'printx' },
    },
}
```
_PS: I'll ignore sometimes the position field in this document for making easier writing the examples._

User could also annotate a lexical rule as a `keyword` for appending a `!ID_END` at the end, but currently the second feature, ensuring none keyword is matched as identifier, is not supported for these rules. Here goes an example:
```peg
s <- (init / idx)+
init <- VECTOR ID
idx <- ID '.' INT

keyword VECTOR <- 'vector' [1-9]
INT <- %d+

SKIP <- (' ' / '\n' / ';')*
```
When matching this input:
```
                vector3 vector3D
                ;;;;
                vector3D.2
```
the following AST is returned:
```lua
{
    tag = 's', pos = 17,
    {
        tag = 'init', pos = 17,
        { tag = 'VECTOR', pos = 17, 'vector3' },
        { tag = 'ID', pos = 25, 'vector3D' },
    },
    {
        tag = 'idx', pos = 71,
        { tag = 'ID', pos = 71, 'vector3D' },
        { tag = 'INT', pos = 80, '2' },
    },
}
```

### Skippable nodes
Sometimes the user would like to define some rules for ensuring associativity or precedence between operators but that could result in very linear and tedious ASTs. The user could use skippable nodes using `<~` instead of `<-` for capturing just the child node instead of creating a new parent node, if there is only one child node. Otherwise,a new parent node is captured as always. Here goes an example:
```peg
exp         <-  conj (`or` conj)*
conj        <~  comp (`and` comp)*
comp        <~  conc (COMP_OP conc)*
conc        <~  arit ('..' arit)*
arit        <~  term (TERM_OP term)*
term        <~  factor (FACTOR_OP factor)*
factor      <~  unary ('^' unary)*
unary       <~  UNARY_OP* atom_exp
```
That way, when matching _`4`_, the AST captured is:
```lua
{
    tag = 'exp',
    { tag = 'NUMBER', '10' },
}
```
but when matching _`4 + x/2`_ it is:
```lua
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
``` 

### Fragments
Sometime the user would like to create rules just for improving the readability, hence the user would not like them to return new parent nodes. Rules annotated as `fragment` are a good fit for that. Here goes an example:
```peg
assign <- ID '=' number
fragment number <- FLOAT / INT
INT <- %d+
FLOAT <- %d+ '.' %d+
```

When matching _`x = 255`_, the AST is like this:
```lua
{ 
    tag = 'assign', 
    { tag = 'ID', 'x' }, 
    { tag = 'INT', '255' } 
}
```
and when matching `a_2 = 3.141516`, it is like this:
```lua
{
    tag = 'assign',
    { tag = 'ID', 'a_2' },
    { tag = 'FLOAT', '3.1416' },
}
```

### Semantic actions
Sometimes the user would like to perform some code after matching a pattern. For that, the user can provide a table of functions as a second argument to the `generator.gen` function. Then, in the grammar, the user can call a function like this:
```peg
a_rule <- { a_pattern , a_function }
```
The given function gets as arguments the entire subject, the current position (after the match of `a_pattern`), plus any capture values produced by `a_pattern`. The symbol `a_rule` could be syntactic or lexical.

The first value returned by `a_function` defines how the match happens. If the call returns a number, the match succeeds and the returned number becomes the new current position. (Assuming a subject `s` and current position `i`, the returned number must be in the range _`[i, len(s) + 1]`_.) If the call returns `true`, the match succeeds without consuming any input. (So, to return true is equivalent to return `i`.) If the call returns `false`, `nil`, or no value, the match fails. 

### Named groups
The user can group all values returned by a pattern into a single named capture which can be returned in other places in the grammar. To name a group the user writes something like this:
```peg
a_rule <- { a_pattern : a_name }
```
Again, `a_rule` could be lexical or syntactic. After doing this, considering `a_rule` as a syntactic rule, the captures of `a_pattern` won't be in the array of `a_rule`. If the user wants to return those captures, now grouped or labeled as `a_name`, they can use the operator `^` for **back captures** like this:
```peg
s <- { "="* : equals} ^equals
```
Keep in mind that `^equals` could be used anywhere in the grammar, returning the captures of the most recent group capture named `equals`. 

_Most recent_ means the last complete outermost group capture with the given name. A _complete_ capture means that the entire pattern corresponding to the capture has matched. An _outermost_ capture means that the capture is not inside another complete capture.

A good example that uses semantic actions, named groups and back captures is the grammar for Lua long strings:

```peg
LONG_STR    <-  { OPEN_STR : init_eq } '\n'? (!CLOSE_EQ .)* CLOSE_STR
EQUALS      <-  '='*
OPEN_STR    <-  '[' EQUALS '['
CLOSE_STR   <-  ']' EQUALS ']'
CLOSE_EQ    <-  { CLOSE_STR ^init_eq , check_eq }
```
where `close_eq` is defined as follows:
```lua
function(subject, pos, closing, opening)
    return #closing[1] == #opening[1]
end
```

___
This project is part of the Google Summer of Code 2020. I am writing [some posts](https://dev.to/_gusgustavo/my-project-for-gsoc-2020-a-parser-generator-with-automatic-error-recovery-on-lpeg-label-3o2) about my journey building it.

## About the name
The parser generator is called Caribay, the daughter of Zuhé (the Sun) and Chía (the Moon) from a legend of the Mirripuyes (an indigenous group from Mérida, Venezuela). Since Lua means "Moon" in Portuguese, the tool being the daughter of Lua sounded nice to me. Also, the legend involves the origin of five famous peaks from Mérida, so the name is related to "generating" things.
