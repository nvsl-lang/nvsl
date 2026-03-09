# Grammar

This file describes the current `NVSL` grammar in a practical EBNF-style form.

It documents the frozen core syntax, not future optional host libraries.

## Lexical Notes

### Identifiers

Identifiers use the normal programming-language shape:

- start with a letter or `_`
- continue with letters, digits, or `_`

Examples:

```txt
score
hero_name
_internal
Scene01
```

### Qualified Paths

Qualified names are dot-separated identifiers:

```txt
game.state
types.Character
std.repeat
```

### Literals

Supported literal kinds:

- `Int`
- `Float`
- `String`
- `Bool`

Examples:

```txt
1
42
3.14
"hello"
true
false
```

### Comments

Comments are not documented as part of the frozen grammar yet. If comment syntax is added later, it should be documented here explicitly instead of being assumed.

## File Grammar

```txt
file            ::= moduleDecl importDecl* topLevelDecl* EOF
moduleDecl      ::= "module" qualifiedName ";"
importDecl      ::= "import" qualifiedName ("as" identifier)? ";"
```

Examples:

```txt
module game.state;

import common.types;
import common.types as types;
```

## Top-Level Declarations

```txt
topLevelDecl    ::= valueDecl
                  | functionDecl
                  | structDecl
                  | enumDecl
```

### Top-Level `let`

```txt
valueDecl       ::= "let" identifier ":" typeRef "=" expr ";"
```

Top-level `let` must always declare a type.

Example:

```txt
let score: Int = 0;
```

### Top-Level `fn`

```txt
functionDecl    ::= "fn" identifier "(" paramList? ")" "->" typeRef functionBody
functionBody    ::= blockExpr
                  | "=" expr ";"
paramList       ::= param ("," param)*
param           ::= identifier ":" typeRef
```

Examples:

```txt
fn nextScore(delta: Int) -> Int {
	score + delta
}

fn nextScore(delta: Int) -> Int = score + delta;
```

### `struct`

```txt
structDecl      ::= "struct" identifier "{" structField* "}"
structField     ::= identifier ":" typeRef ";"
```

Example:

```txt
struct Character {
	name: String;
	tags: List<String>;
}
```

### `enum`

```txt
enumDecl        ::= "enum" identifier "{" enumCase* "}"
enumCase        ::= identifier ";"
```

Example:

```txt
enum Mood {
	Warm;
	Cold;
}
```

## Statements

Statements only exist inside block expressions.

```txt
statement       ::= localLetStmt
                  | setStmt
                  | exprStmt
localLetStmt    ::= "let" identifier (":" typeRef)? "=" expr ";"
setStmt         ::= "set" identifier "=" expr ";"
exprStmt        ::= expr ";"
```

Notes:

- local `let` may omit the type if the checker can infer it
- `set` only accepts a simple identifier target
- field assignment and index assignment are not part of the grammar

Examples:

```txt
let next: Int = score + 1;
let label = std.repeat("go", 2);
set score = score + 1;
std.toString(score);
```

## Expressions

```txt
expr            ::= ifExpr
                  | lambdaExpr
                  | binaryExpr
```

### `if`

```txt
ifExpr          ::= "if" expr blockExpr "else" blockExpr
```

Example:

```txt
if score > 0 { "positive" } else { "zero" }
```

### Lambda

```txt
lambdaExpr      ::= "fn" "(" paramList? ")" ("->" typeRef)? "=>" expr
```

Example:

```txt
fn(value: Int) -> Int => value + 1
```

### Blocks

```txt
blockExpr       ::= "{" statement* tailExpr? "}"
tailExpr        ::= expr
```

Rules:

- semicolons are required for statements
- the final expression in a block has no semicolon
- if there is no tail expression, the block result is `Void`

Example:

```txt
{
	let next: Int = score + 1;
	next
}
```

### Primary Expressions

```txt
primaryExpr     ::= literal
                  | pathExpr
                  | listLiteral
                  | recordLiteral
                  | "(" expr ")"
                  | blockExpr
```

### Paths

```txt
pathExpr        ::= qualifiedName
qualifiedName   ::= identifier ("." identifier)*
```

Examples:

```txt
score
types.Mood.Warm
game.state.currentHero
std.repeat
```

### Lists

```txt
listLiteral     ::= "[" (expr ("," expr)*)? "]"
```

Current semantic rule:

- empty list literals are rejected by the checker

Example:

```txt
["pilot", "friend"]
```

### Records

```txt
recordLiteral   ::= qualifiedName "{" recordFieldInit ("," recordFieldInit)* "}"
recordFieldInit ::= identifier ":" expr
```

Example:

```txt
types.Character {
	name: "Ava",
	tags: ["pilot", "friend"]
}
```

### Postfix Operations

```txt
postfixExpr     ::= primaryExpr postfixOp*
postfixOp       ::= "." identifier
                  | "[" expr "]"
                  | "(" argumentList? ")"
argumentList    ::= expr ("," expr)*
```

Examples:

```txt
hero.name
hero.tags[0]
state.currentHero()
std.join(hero.tags, ", ")
```

### Unary Operators

```txt
unaryExpr       ::= ("-" | "!") unaryExpr
                  | postfixExpr
```

### Binary Operators

Operators are parsed by precedence.

```txt
binaryExpr      ::= logicOrExpr
logicOrExpr     ::= logicAndExpr ("||" logicAndExpr)*
logicAndExpr    ::= equalityExpr ("&&" equalityExpr)*
equalityExpr    ::= comparisonExpr (("==" | "!=") comparisonExpr)*
comparisonExpr  ::= additiveExpr (("<" | "<=" | ">" | ">=") additiveExpr)*
additiveExpr    ::= multiplicativeExpr (("+" | "-") multiplicativeExpr)*
multiplicativeExpr ::= unaryExpr (("*" | "/" | "%") unaryExpr)*
```

## Types

```txt
typeRef         ::= simpleTypeRef ("<" typeRef ("," typeRef)* ">")?
simpleTypeRef   ::= qualifiedName
```

Built-in names:

- `Void`
- `Int`
- `Float`
- `String`
- `Bool`
- `List<T>`

User-defined names:

- `struct` types
- `enum` types

Examples:

```txt
Int
String
List<String>
types.Character
common.types.Mood
```

## Summary Of What Is Not In Grammar

These are intentionally absent:

- loops
- classes
- methods
- field assignment
- index assignment
- `switch`
- pattern matching
- imports from host packages
- arbitrary host calls
