#!/usr/bin/env bash
# Milestone 4: generated C against emil. Usage: scripts/run-m4.sh [TOOLS_DIR]. Changes nothing in emil.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${1:-${TOOLS_DIR:-$HOME/tools}}"; EM="$TOOLS_DIR/emil"; T="$here/tests"; P="$here/acl2/atc-scalar"
B="$here/build/m4"; mkdir -p "$B"; cd "$B"
awk '/^int adjustPoint/{p=1} p{print} p&&/^}/{exit}' "$EM/adjust.c" > emil_only.c
sed 's/^int adjustPoint/int emil_adjustPoint/' emil_only.c > emil_renamed.c
# Exact copy of the generated files' compile: warnings on, sanitizers on
W="-std=c99 -Wall -Wextra -Wpedantic -Wconversion"
for cc in gcc clang; do
  $cc $W -I"$P" -c "$P/adjust_scalar.c" -o /dev/null 2> "$cc.gen.warnings" || true
  $cc $W -I"$P" -c "$P/adjust_wrapper.c" -o /dev/null 2> "$cc.wrap.warnings" || true
  echo "$cc warnings: generated=$(grep -c 'warning:' "$cc.gen.warnings" || true) wrapper=$(grep -c 'warning:' "$cc.wrap.warnings" || true) kinds: $(grep -ho '\[-W[^]]*\]' "$cc.gen.warnings" | sort -u | tr '\n' ' ')"
done
GEN="-DadjustPoint=gen_adjustPoint -I$P"
S="-std=c99 -D_DEFAULT_SOURCE -O1 -g -w -fsanitize=address,undefined -fno-sanitize-recover=all"
echo "== model check of the generated C and wrapper: M1 domain"
gcc $S -I"$P" "$T/m1/harness.c" "$P/adjust_scalar.c" "$P/adjust_wrapper.c" -o h-gen && ./h-gen | grep -E 'bounds|texts='
echo "== exhaustive differential on the M1 domain, sanitizers on"
for cc in gcc clang; do
  $cc $S -c "$P/adjust_scalar.c" -I"$P" -o scalar.o
  $cc $S $GEN -c "$P/adjust_wrapper.c" -o wrap.o
  $cc $S "$T/m1/harness.c" "$T/m4/shim.c" emil_renamed.c scalar.o wrap.o -o "diff-$cc"
  echo "-- $cc"; "./diff-$cc" 2>&1 | grep -E 'texts=|differential|DIFF' | head -12
done
echo "== large values within the proven guard, sanitizers on"
gcc $S -c "$P/adjust_scalar.c" -I"$P" -o scalar.o; gcc $S $GEN -c "$P/adjust_wrapper.c" -o wrap.o
gcc $S "$T/m4/diff_large.c" emil_renamed.c scalar.o wrap.o -o large; ./large "${M4_RANDOM:-100000000}"
echo "== control: seeded large-value bugs must be caught by that test"
for m in M15 M16; do
  sed 's/^int adjustPoint/int emil_adjustPoint/' <(awk '/^int adjustPoint/{p=1} p{print} p&&/^}/{exit}' "$B/../m1/mut/$m.c") > ctrl.c
  gcc -std=c99 -O1 -w -I"$P" "$T/m4/diff_large.c" ctrl.c "$P/adjust_scalar.c" -DadjustPoint=gen_adjustPoint "$P/adjust_wrapper.c" -o ctrl
  if ./ctrl 2000000 > ctrl.out; then echo "$m: NOT caught"; else echo "$m: caught ($(grep 'total differences' ctrl.out))"; fi
done
