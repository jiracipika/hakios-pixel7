#!/usr/bin/env bash
# dt-from-sysfs.sh — capture the Pixel 7's applied device tree over adb (unrooted) and
# rebuild a binary DTB. /sys/firmware/devicetree/base is the tree ABL handed the kernel;
# readable by the shell user on stock/ROMs where the raw fdt blob is not.
# Output (into this script's parent's device/ dir): panther-fdt.dtb + panther-fdt.tree.txt
# usage: dt-from-sysfs.sh    (phone on adb, booted to Android)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUTDIR="$HERE/../device"
mkdir -p "$OUTDIR"

if [ ! -s "$OUTDIR/tree.capture" ]; then
  echo 'capturing tree over adb (hundreds of nodes; a few minutes)...'
  adb shell 'cd /sys/firmware/devicetree/base && find . | while IFS= read -r f; do if [ -d "$f" ]; then printf "=D=%s\n" "$f"; else printf "=F=%s\n" "$f"; base64 "$f" 2>/dev/null; fi; done' > "$OUTDIR/tree.capture"
fi

python3 - "$OUTDIR" <<'PYEOF'
import base64, os, struct, sys
out_dir = sys.argv[1]
raw = open(os.path.join(out_dir, 'tree.capture'), 'rb').read()
lines = raw.split(b'\n')
entries = []
cur = None
for ln in lines:
    if ln.startswith(b'=D='):
        entries.append(('D', ln[3:].decode('utf-8', 'replace'), None)); cur = None
    elif ln.startswith(b'=F='):
        cur = ('F', ln[3:].decode('utf-8', 'replace'), b''); entries.append(cur)
    elif cur is not None:
        cur[2] += base64.b64decode(ln.strip() or b'')
print(f'captured {len(entries)} entries')

class Node:
    def __init__(self, name): self.name, self.props, self.children = name, [], []
root = Node('/')
for kind, path, data in entries:
    parts = [p for p in path.split('/') if p and p != '.']
    node = root
    for p in parts[:-1]:
        nxt = next((c for c in node.children if c.name == p), None)
        if nxt is None: nxt = Node(p); node.children.append(nxt)
        node = nxt
    if kind == 'D':
        if parts and not any(c.name == parts[-1] for c in node.children):
            node.children.append(Node(parts[-1]))
    elif parts:
        node.props.append((parts[-1], data))

strings = bytearray(); stroff = {}
def strof(s):
    if s not in stroff:
        stroff[s] = len(strings); strings += s.encode() + b'\0'
    return stroff[s]
structs = bytearray()
def w32(v): return struct.pack('>I', v)
def emit(node, name='/'):
    structs.extend(w32(1)); structs.extend(name.encode() + b'\0' + b'\0' * (-(len(name) + 1) % 4))
    for pn, pd in node.props:
        structs.extend(w32(3)); structs.extend(w32(len(pd))); structs.extend(w32(strof(pn)))
        structs.extend(pd); structs.extend(b'\0' * (-len(pd) % 4))
    for c in sorted(node.children, key=lambda n: n.name): emit(c, c.name)
    structs.extend(w32(2))
emit(root)
structs.extend(w32(9))
while (40 + len(structs)) % 8: structs += b'\0'
str_off = 40 + len(structs)
total = str_off + len(strings)
hdr = struct.pack('>12I', 0xd00dfeed, total, 40, 40, 40, 17, 0, 0,
                  len(strings), str_off, total, 40)
out = hdr + bytes(structs) + bytes(strings)
assert len(out) == total, (len(out), total)
open(os.path.join(out_dir, 'panther-fdt.dtb'), 'wb').write(out)
print(f'wrote panther-fdt.dtb ({len(out)} bytes, strings {len(strings)}b)')
with open(os.path.join(out_dir, 'panther-fdt.tree.txt'), 'w') as f:
    def dump(node, depth):
        f.write('  ' * depth + node.name + '\n')
        for pn, pd in node.props:
            f.write('  ' * (depth + 1) + pn + ' = ' + (pd[:24].hex() + ('...' if len(pd) > 24 else '')) + f' ({len(pd)}b)\n')
        for c in node.children: dump(c, depth + 1)
    dump(root, 0)
print('wrote panther-fdt.tree.txt')
PYEOF
rm -f "$OUTDIR/tree.capture"
ls -la "$OUTDIR"
