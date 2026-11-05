#!/usr/bin/env bash
# Parse the generated C with C$ and compare with *program*. Evidence about this one
# output, not proof of the printer: the same library printed the file.
# Needs the replay book from scripts/certify.sh and kestrel/c/syntax/input-files certified.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${1:-${TOOLS_DIR:-$HOME/tools}}"; W="$here/build/roundtrip"; rm -rf "$W"; mkdir -p "$W"; cd "$W"
cp "$here/acl2/atc-scalar/adjust_scalar.c" "$here/acl2/atc-scalar/adjust_scalar.h" .
sed "s#REPLAY#$here/build/replay/three-functions/three-functions-replay#" "$here/experiments/c-roundtrip/roundtrip.lsp" > run.lsp
ACL2_CUSTOMIZATION=NONE "$TOOLS_DIR/acl2/saved_acl2" < run.lsp > run.out 2>&1
grep ROUNDTRIP run.out
python3 - <<'PY'
a, b = open('cmp.txt').read().strip().split('\n')
n = a.replace('(C::VALUE . 0) (C::BASE :OCT)', '(C::VALUE . 0) (C::BASE :DEC)')
print('literal 0 tagged octal after parsing:', a.count('(C::BASE :OCT)'))
print('identical after normalising that tag:', n == b)
PY
