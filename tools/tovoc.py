#!/usr/bin/env python3
# tovoc.py polpo-file voc-file: a module shared with voc, with the imports of voc.
# The shared modules (the voc repositories on github.com/norayr, main, master for Internet):
#   src/lib/sockets/Sockets.Mod, src/lib/dns/DNS.Mod, src/lib/internet/Internet.Mod -> Internet
#   src/lib/strutils/strUtils.Mod, strTypes.Mod -> strutils
#   src/lib/base64/Base64.Mod -> base64
#   src/lib/http/http.Mod, hexIntStr.Mod -> http
# Only the import lines differ; files without them are copied unchanged.
import sys, re
s = open(sys.argv[1]).read()
swaps = [
 ("IMPORT S := strTypes, Strings := strings, Out := out;  (* voc: Strings := ooc2Strings, Out *)",
  "IMPORT S := strTypes, Strings := ooc2Strings, Out;  (* polpo: Strings := strings, Out := out *)"),
 ("IMPORT Out := out, Strings := strings;  (* voc: Out, Strings *)",
  "IMPORT Out, Strings;  (* polpo: Out := out, Strings := strings *)"),
 ("IMPORT Sockets, DNS, Linux0, Out := out, SYSTEM;  (* voc: Out *)",
  "IMPORT Sockets, DNS, Linux0, Out, SYSTEM;  (* polpo: Out := out *)"),
 ("IMPORT IntStr := oocIntStr, Strings := strings, Files, Out := out,  (* voc: Strings, Out *)",
  "IMPORT IntStr := oocIntStr, Strings, Files, Out,  (* polpo: Strings := strings, Out := out *)"),
]
n = 0
for a, b in swaps:
    if a in s: s = s.replace(a, b); n += 1
open(sys.argv[2], 'w').write(s)
print(sys.argv[1].split('/')[-1], 'imports changed' if n else 'unchanged')
