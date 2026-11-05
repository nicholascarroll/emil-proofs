#!/usr/bin/env bash
# Compile the ATC-generated prototypes and smoke-test them against emil's function.
# Usage: scripts/smoke-m0.sh [TOOLS_DIR]. Run after scripts/certify.sh.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${1:-${TOOLS_DIR:-$HOME/tools}}"
P="$here/acl2/atc-proto"; B="$here/build/m0"; mkdir -p "$B"
# Copy only adjustPoint from emil's read-only clone, so emil.h isn't needed
awk '/^int adjustPoint/{p=1} p{print} p&&/^}/{exit}' "$TOOLS_DIR/emil/adjust.c" \
  | sed 's/^int adjustPoint/int emil_adjustPoint/' > "$B/emil_adjust.c"
F="-std=c99 -Wall -Wextra -Wpedantic -Wconversion -O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all"
for cc in gcc clang; do
  # Warnings are findings, so they're shown and counted rather than fatal
  $cc $F -I"$P" "$P/tiny.c" "$P/adjust_shape.c" "$B/emil_adjust.c" "$here/tests/m0/smoke.c" -o "$B/smoke-$cc" 2> "$B/$cc.warnings"
  echo "== $cc: $(grep -c 'warning:' "$B/$cc.warnings" || true) warnings"
  grep 'warning:' "$B/$cc.warnings" | sed -E 's/.*\[(-W[^]]*)\].*/\1/' | sort | uniq -c || true
  "$B/smoke-$cc"
done
