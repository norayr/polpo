RXA Regular Expressions

Commands

rx.SetSearch [-c] expression
rx.SetReplace replacement
rx.Search [text]
rx.Replace [text]
rx.ReplaceAll [text]
rx.Grep file-pattern [-ci] expression

SetSearch compiles and remembers an RXA expression.  SetReplace remembers a
replacement expression.  Search with a text argument starts a new search;
Search without an argument continues after the previous match.  Replace and
ReplaceAll print transformed text.  They do not modify files or UI frames.

Grep searches ASCII and Oberon text files and prints filename:line:text.
File patterns may contain * and ?.  Option -c ignores letter case.  Grep option
-i prints lines that do not match.

RXA expression syntax

RegExpr      = term { "|" term }.
term         = factor { factor }.
factor       = "(" RegExpr ")" | "[" RegExpr "]" | "{" RegExpr "}"
             | ["~"] (quoted-literal | shorthand).
subexpression = factor X0 | factor X1 | ... | factor X9.

(...) groups an expression.
[...] makes an expression optional; it is not a POSIX character class.
{...} repeats an expression zero or more times.
| selects alternatives.
~ negates one quoted character or shorthand.
"text" matches literal text.
X0 through X9 mark captured subexpressions for replacement.

Shorthands

A  uppercase letter       a  lowercase letter
b  binary digit           c  carriage return
d  decimal digit          h  hexadecimal digit
i  letter or digit        l  letter
o  octal digit            t  tab
w  tab, carriage return, or blank

Examples

Find a literal and continue to the next match:

rx.SetSearch "a"
rx.Search banana
rx.Search

Replace every occurrence in a text argument:

rx.SetSearch "a"
rx.SetReplace "A"
rx.ReplaceAll banana

Capture a module path and use it twice in the replacement:

rx.SetSearch {i | "." | "/"} X0 ".Mod"
rx.SetReplace X0 ".Mod => " X0 ".Mod"
rx.Replace src/common/RXA.Mod

Search source files with the original RXA grammar:

rx.Grep src/common/*.Mod "PROCEDURE"
rx.Grep src/common/*.Mod -c "module"
rx.Grep src/common/*.Mod -i "PROCEDURE"

Conventional grep commands use the separate regex module:

grep.Word PROCEDURE src/common/*.Mod
grep.Regex "^MODULE [A-Za-z]+;$" src/common/*.Mod
