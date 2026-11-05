#!/usr/bin/env bash
# Run emil's key fuzzer with a history-matches-text check after every key.
# Usage: tests/undo/fuzz_history.sh EMIL_REPO COMMIT WORK_DIR FIRST COUNT
# WORK_DIR must not exist. Exports the commit, patches the copy of tests/fuzz_keys.c, and
# runs as an unprivileged user because the key stream can type file names.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$1"; commit="$2"; work="$3"; first="$4"; count="$5"
mkdir -p "$(dirname "$work")"; mkdir "$work"; mkdir "$work/src"
git -C "$repo" archive "$commit" | tar -x -C "$work/src"
cp "$here/history_check.c" "$work/src/tests/history_check.inc"
python3 - "$work/src/tests/fuzz_keys.c" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace('static void runSequence(uint32_t seed) {','#include "history_check.inc"\n\nstatic void runSequence(uint32_t seed) {',1)
assert 'processKeypress(cmd);' in s
s=s.replace('processKeypress(cmd);','processKeypress(cmd); historyCheckAll();',1)
open(p,'w').write(s)
PY
chmod -R a+rwX "$work"
cd "$work/src"
setpriv --reuid=65534 --regid=65534 --clear-groups env TMPDIR="$work" FUZZ_WORK="$work/fz" sh tests/fuzz_keys.sh "$first" "$count"
