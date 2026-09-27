# Oberon.Text: reading configuration

`Oberon.Text` is the configuration text of the system: `System.FontScale`,
`System.LineSpacing`, `System.InitCommands` and the others are read from it. Any
program can keep its own settings there and read them with the same scanner.

## The file

Entries are `Name = value` pairs. A value is a number, a name, a `"string"`, or a
group `{ ... }` holding more pairs or a list of items. Comments are written `{* ... *}`.

```
System = {
  FontScale = 150  {* screen font scale in percent *}
  LineSpacing = 150
  InitCommands = { { System.OpenLog } { System.Open System.Tool } }
}

MyTool = {
  Size = 10
  Host = "example.org"
  Colors = { red green blue }
}
```

`Oberon.Text` can be a plain text or an Oberon text. It is found through the
file search path: the current directory first, then the polpo root (and `share/`,
`tools/`). A copy in the current directory therefore overrides the one in the root.

## The scanner

```oberon
Oberon0.OpenScanner(S, "Section.Key")   (* console modules, src/common/Oberon0.Mod *)
Oberon.OpenScanner(S, "Section.Key")    (* desktop modules; it calls Oberon0.OpenScanner *)
```

`S` is a `Texts.Scanner`. The key is a dotted path through the groups, to any depth
(`"Printer.LPRPrinter.Resolution"`). After the call the scanner stands on the value,
and `S.class` tells what is there:

| `S.class`                    | value                                          |
|------------------------------|------------------------------------------------|
| `Texts.Int`                  | an integer, in `S.i`                           |
| `Texts.Real`                 | a real number, in `S.x`                        |
| `Texts.Name`, `Texts.String` | a name or a `"string"`, in `S.s`               |
| (anything)                   | a group: the scanner is already inside it, on its first item |
| `Texts.Inval`                | the key is not in `Oberon.Text`: use a default |

To read a group, keep calling `Texts.Scan(S)` until the closing `}` (a `Texts.Char`
with `S.c = "}"`) or `S.eot`. `System.Init` walks `InitCommands` this way.

The text is kept in memory and read again only when the file's date changes. Lookups
are cheap, and an edited `Oberon.Text` is picked up without restarting.

## Example

A console module (desktop modules import `Texts` and `Oberon` and call `Oberon.OpenScanner`):

```oberon
MODULE mytool;
IMPORT Texts := texts, Oberon := Oberon0, out;

PROCEDURE Show*;
VAR S: Texts.Scanner; size: LONGINT;
BEGIN
  size := 12;  (* default *)
  Oberon.OpenScanner(S, "MyTool.Size");
  IF S.class = Texts.Int THEN size := S.i END;
  out.String("size "); out.Int(size, 0); out.Ln;

  Oberon.OpenScanner(S, "MyTool.Host");
  IF S.class IN {Texts.Name, Texts.String} THEN out.String(S.s); out.Ln END;

  Oberon.OpenScanner(S, "MyTool.Colors");  (* a group: the scanner is on "red" *)
  WHILE (S.class = Texts.Name) & ~S.eot DO
    out.String(S.s); out.Char(" "); Texts.Scan(S)
  END;
  out.Ln
END Show;

END mytool.
```

```
$ bin/x86/loksh mytool.Show
size 10
example.org
red green blue
```

## An environment variable as override

`OFONTSCALE` overrides `System.FontScale` by reading the environment first and
`Oberon.Text` only when the variable is not set:

```oberon
Kernel.GetConfig("MYTOOLSIZE", s);
IF s[0] # 0X THEN (* convert s *)
ELSE
  Oberon.OpenScanner(S, "MyTool.Size");
  IF S.class = Texts.Int THEN size := S.i END
END
```

## Details

* Names are case-sensitive, and each part of a key has at most 31 characters.
* Names and strings are read into `S.s`, which holds 63 characters.
* The first matching entry wins.
* A group `{ ... }` without a name is skipped, which is how comments work.
  So braces inside a comment must be balanced.
