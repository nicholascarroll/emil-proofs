#!/usr/bin/env bash
# Milestone 1 and the Milestone 2 C evidence: rebuild and rerun everything against
# emil's read-only clone. Usage: scripts/run-m1.sh [TOOLS_DIR] [--with-5x5]
# Writes results to build/m1 and build/m2. About 8 minutes; --with-5x5 adds about 8 more.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${1:-${TOOLS_DIR:-$HOME/tools}}"; EM="$TOOLS_DIR/emil"; T="$here/tests"
B="$here/build/m1"; mkdir -p "$B" "$here/build/m2"; cd "$B"
EMIL="-std=c99 -D_DEFAULT_SOURCE -O2 -w -I$EM"
gcc $EMIL -c "$EM/adjust.c" -o adjust.o
gcc $EMIL -c "$T/m1/emil_stub.c" -o stub.o
gcc -std=c99 -O2 -Wall -Wextra -Wconversion "$T/m1/harness.c" adjust.o stub.o -o harness
./harness | tee full.out
for cc in gcc clang; do
  $cc -std=c99 -D_DEFAULT_SOURCE -O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all \
      -w -I"$EM" "$T/m1/harness.c" "$EM/adjust.c" "$T/m1/emil_stub.c" -o "harness-san-$cc"
  echo "== sanitized $cc"; "./harness-san-$cc" | grep texts=
done
# Emil's own test file, built in a scratch copy of its source
rm -rf emil-copy; cp -r "$EM" emil-copy; rm -rf emil-copy/.git
make -C emil-copy -j2 > emil-make.log 2>&1
cc -std=c99 -D_DEFAULT_SOURCE -O2 -w -Iemil-copy -Iemil-copy/tests -c emil-copy/tests/stubs.c -o emil-copy/tests/stubs.o
sh "$T/m1/link_test_adjust.sh" "$B/emil-copy" "$B/emil-copy/ta"
echo "== emil's test_adjust"; (cd emil-copy && ./ta | tail -2)
python3 "$T/m1/mutants.py" "$EM" "$B" "$T/m1/harness.c" "$T/m1/emil_stub.c" "$B/emil-copy" | tee mutants.out
# Mutants replaced adjust.o in the copy; put the real one back for the stale test
cc -std=c99 -D_DEFAULT_SOURCE -O2 -w -Iemil-copy -c emil-copy/adjust.c -o emil-copy/adjust.o
OBJ="decoder.o unicode.o buffer.o region.o undo.o transform.o find.o pipe.o register.o fileio.o display.o keymap.o edit.o prompt.o util.o completion.o history.o base64.o abuf.o window.o ctags.o adjust.o mutate.o wrap.o motion.o dbuf.o emil_subprocess.o palette.o backup.o message.o tests/stubs.o"
(cd emil-copy && cc -std=c99 -D_DEFAULT_SOURCE -O1 -g -w -I. -Itests "$T/m2/stale_window.c" $OBJ -o stale && echo "== stale window" && ./stale)
cd "$here/build/m2"
P="$here/acl2/atc-scalar"; F="-std=c99 -D_DEFAULT_SOURCE -O1 -w -fsanitize=signed-integer-overflow -fno-sanitize-recover=all"
awk '/^int adjustPoint/{p=1} p{print} p&&/^}/{exit}' "$EM/adjust.c" > emil_only.c
gcc $F "$T/m2/overflow_exact.c" emil_only.c -o ov-emil
gcc $F -I"$P" "$T/m2/overflow_exact.c" "$P/adjust_scalar.c" "$P/adjust_wrapper.c" -o ov-f
echo "== overflow predicate, emil's function"; ./ov-emil | tail -1
echo "== overflow predicate, pointer-free version"; ./ov-f | tail -1
if [ "${2:-}" = "--with-5x5" ]; then echo "== 5x5"; "$B/harness" 5 5 | grep -E 'bounds|texts='; fi
