# Caribay
A PEG (Parsing Expression Grammar) Parser Generator built with LPeg(Label). The generated parser captures a generic AST (Abstract Syntactic Tree).

Caribay makes easier to parse lexical symbols, comments, identifiers and keywords.

## Table of contents
1. [Installation](#installation)
2. [Usage](#usage)
3. [Syntax and examples](#syntax-and-examples)
4. [Error Labels](#error-labels)
    1. [Manually inserted labels](#manually-inserted-labels) 
    2. [Automatically inserted labels](#automatically-inserted-labels)
    3. [Recovery Rules](#recovery-rules)

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
then you call the `gen` function passing a PEG as argument to generate an LPegLabel parser:
```lua
local src = [[
    assign <- ID '=' number
    fragment number <- FLOAT / INT
    INT <- %d+
    FLOAT <- %d+ '.' %d+
]]
local match = generator.gen(src)
match[[     a_2     =   3.1416 ]]
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
SKIP <- (' ' / '\t' / '\n' / '\f' / '\r')*
```
If the user defines a `COMMENT` rule, `SKIP` is defined as follows:
```peg
SKIP <- (' ' / '\t' / '\n' / '\f' / '\r' / COMMENT)*
```

_Note: Actually, instead of `' ' / '\t' / '\n' / '\f' / '\r'`, it uses `lpeg.space`, which uses C [`isspace`](http://www.cplusplus.com/reference/cctype/isspace/)._
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

 Any extra values returned by the function become the values produced by the capture (which is only useful in syntactic rules). 

### Named groups
The user can group all values returned by a pattern into a single named capture which can be returned in other places in the grammar. To name a group the user writes something like this:
```peg
a_rule <- { a_pattern : a_name }
```
Again, `a_rule` could be lexical or syntactic. After doing this, considering `a_rule` as a syntactic rule, the captures of `a_pattern` won't be in the array of `a_rule`. If the user wants to return those captures, now grouped or labeled as `a_name`, they can use the operator `=` for **back captures** like this:
```peg
s <- { "="* : equals} =equals
```
Keep in mind that `=equals` could be used anywhere in the grammar, returning the captures of the most recent group capture named `equals`. 

_Most recent_ means the last complete outermost group capture with the given name. A _complete_ capture means that the entire pattern corresponding to the capture has matched. An _outermost_ capture means that the capture is not inside another complete capture.

A good example that uses semantic actions, named groups and back captures is the grammar for Lua long strings:

```peg
LONG_STR    <-  { OPEN_STR : init_eq } '\n'? (!CLOSE_EQ .)* CLOSE_STR
EQUALS      <-  '='*
OPEN_STR    <-  '[' EQUALS '['
CLOSE_STR   <-  ']' EQUALS ']'
CLOSE_EQ    <-  { CLOSE_STR =init_eq , check_eq }
```
where `close_eq` is defined as follows:
```lua
function(subject, pos, closing, opening)
    return #closing[1] == #opening[1]
end
```

### Labels
See [this section](#manually-inserted-labels)

## Error Labels
The result of an unsuccessful matching is a triple `nil, lab, errpos`, where `lab` is the label associated with the failure, and `errpos` is the input position being matched when `lab` was thrown.

### Manually inserted labels
Use `^` operator.
```peg
numbers <- ((INT / HEX / FLOAT)^ErrNumber)+
```

### Automatically inserted labels
The generator will try to automatically create some error labels. In order to identify the safe places where Caribay can insert labels, the concept of unique lexical non-terminals is used: _a lexical non-terminal A is unique when it appears in the right-hand
side of only one syntactical rule, and just once._

An automatically inserted label will be named after its rule and the symbol annotated. See some examples of labels:

- `s_NUMBER`: The symbol `NUMBER` in the rule of `s` is annotated with this label.
- `assignment_=`: The symbol `=` in the rule of `assignment` is annotated with this label.
- `conditional_IF_2`: A symbol `IF` in the rule of `conditional` is annotated with this label. The suffix `_2` means there is already another symbol `IF` in `conditional` annotated with the label `conditional_IF`.

The label `EOF` is automatically generated for the cases where it is not possible to match the whole input. The label `fail` is thrown when Caribay was not able to generate an error label for that specific case (some optimizations are in the ToDo list of this project).

The user can pass `true` as a third argument to `generator.gen` for enabling the **Unique Context Optimization** or **UCO** for incrementing the number of automatically inserted labels using more AST traversals. The reasoning behind this optimization is the following:

_If the lexical non-terminal A is used more than once in
grammar G but the set S of tokens that may occur immediately before an
usage of A is unique, i.e., ∀s ∈ S we have that s may not occur immediately
before the other usages of A, then we can mark this instance of A preceded
by S as unique._

#### Examples

##### Example 1
```peg
s <- (print / assign)+
assign <- ID '=' INT
INT <- %d+
print <- `print` ID
```
The labels automatically inserted without UCO are `assign_INT` and `print_ID`, while `assign_=` is also inserted when using UCO.

`match('x 10')` will throw `assign_=` when using UCO.

`match('x = print 2')` will throw `assign_INT` at position 5.

`match('print 2')` will throw `print_ID` at position 7.

`match('= x = 10')` will throw `fail` at position 1.

##### Example 2
```peg
s <- 'a' 'c' / 'c' 'd'
```

Without UCO, only the label `s_c` is generated, while using UCO the label `s_d` is also generated.

`match('a d')` will throw `s_c` at position 2.

`match('c')` will throw `s_d` at position 2 when using UCO.

##### Example 3
```peg
s <- (init / idx)+
init <- VECTOR ID
idx <- ID '.' INT

keyword VECTOR <- 'vector' [1-9]
INT <- %d+

SKIP <- (' ' / '\n' / ';')*
```

The labels generated without UCO are `idx_INT` and `init_ID`, while using UCO the label `idx_.` is also generated.

`match('vector3D 2)` will throw `fail` without UCO or `idx_.` using UCO, at position 10.

`match('vector3 vector3D ;;.; vector3D.2')` will throw `EOF` at position 20.

`match('vector1 3dvector')` will throw `init_ID` at position 9.

___
### Recovery Rules
`generator.gen` receives a fourth parameter called `create_recovery_rule`. If its value is `nil` or `false`, none recovery rule is created; if its value is `true`, the recovery rule consists of skipping tokens until the parser finds a token that can follow the pattern, this is also called the _panic technique_; otherwise, the function passed is used. 

The function `create_recovery_rule` receives three arguments:
- `generator`: _Generator_
- `label`: _String_
- `flw`: _Set_

This functions is in charge of the logic for creating recovery rules when automatically adding a label. 

You can use this implementation of the panic technique as an example:
```lua
local function panic_technique(generator, label, flw)    
    local recovery_sym_str = Symbol:new(label, 'syn_sym')

    -- Transform set into a LPeg Ordered Choice
    local flw_ord_choice
    for token_key in pairs(flw) do
        if token_key ~= '__$' then
            local ast_token = annotator.key_to_token(token_key, tag)
            local pattern = generator:to_lpeg(ast_token, recovery_sym_str)
            if flw_ord_choice then
                flw_ord_choice = flw_ord_choice + pattern
            else
                flw_ord_choice = pattern
            end
        end
    end

    -- Eat Token
    local eat_token = lp.P(1)

    -- Create recovery rule: R[l] <- (!flw eatToken)*
    return (-flw_ord_choice * eat_token)^0
end
```

_TODO: explained what the user should know for implementing its own_ `create_recovery_rule` _function_.

When calling `match` function, the user can pass a table as second argument which maps error labels to error messages. `generator.gen` returns the array of generated labels as a second returned value for helping to create this table. The returned value by `match` will be a table of _errors_ that are similar to this one:
```lua
{
    line = 2,
    col = 25,
    msg = "Missing '=' in assignment",
},
```
If no table is passed as second argument or no corresponding message is found, the `msg` field will be just the label.

##### Example 4
In this example we are going to generate recovery rules by using the panic technique.

Here is the **grammar** we are going to use, which is very similar to the one from [Example 1](#example-1):
```peg
s <- (print / assign)+
assign <- ID '=' (INT / ID)
INT <- %d+
FLOAT <- %d+ '.' %d+
print <- `print` ID
```

Now we are going to generate our **parser**.

```lua
local match, labs_arr = generator.gen(src, nil, true, true)
```

`labs_arr` looks like this:
```lua
{'assign_=', 'assign_ord_exp', 'print_ID'}
```

Let's now define our table of **error messages**:

```lua
local terror = {
    ['assign_='] = "Missing '=' in assignment",
    ['assign_ord_exp'] = "RValue expected",
    ['print_ID'] = "Valid identifier expected",
    fail = 'Parsing failed',
}
```

This string is going to be our **input**:
```lua
input = [[
    x = 10
    y   11
    z =
    print 2
]]
```

Then, `match(input, terror)` is going to return the following table:
```lua
{
    {
        line = 2,
        col = 25,
        msg = "Missing '=' in assignment",
    },
    {
        line = 4,
        col = 21,
        msg = "RValue expected",
    },
    {
        line = 4,
        col = 27,
        msg = "Valid identifier expected",
    },
}
```

## About the name
The parser generator is called Caribay, the daughter of Zuhé (the Sun) and Chía (the Moon) from a legend of the Mirripuyes (an indigenous group from Mérida, Venezuela). Since Lua means "Moon" in Portuguese, the tool being the daughter of Lua sounded nice to me. Also, the legend involves the origin of five famous peaks from Mérida, so the name is related to "generating" things.

___
___
This project is part of the Google Summer of Code 2020. I am writing [some posts](https://dev.to/_gusgustavo/my-project-for-gsoc-2020-a-parser-generator-with-automatic-error-recovery-on-lpeg-label-3o2) about my journey building it.