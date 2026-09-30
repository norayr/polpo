#!/usr/bin/env python3
# fromvoc.py voc-file... polpo-dir: modules kept in a voc repository (the tls modules of
# github.com/norayr/tls), copied for polpo with the polpo names in their IMPORT clause:
# Out := out, Strings := strings. Everything else is the same file.
import re, sys, os
ALIAS = {'Out': 'out', 'Strings': 'strings'}
def convert(s):
    m = re.search(r'\bIMPORT\b(.*?);', s, re.S)
    if not m: return s
    clause = m.group(1)
    def one(item):
        t = item.strip()
        if ':=' in t or t not in ALIAS: return item
        return item.replace(t, '%s := %s' % (t, ALIAS[t]))
    new = ','.join(one(x) for x in clause.split(','))
    return s[:m.start(1)] + new + s[m.end(1):]
*files, dst = sys.argv[1:]
for f in files:
    s = open(f).read()
    t = convert(s)
    open(os.path.join(dst, os.path.basename(f)), 'w').write(t)
    print(os.path.basename(f), 'imports changed' if t != s else 'same')
