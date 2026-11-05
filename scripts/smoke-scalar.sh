#!/usr/bin/env bash
# Compile the pointer-free prototype and smoke-test it. Run after scripts/certify.sh.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${1:-${TOOLS_DIR:-$HOME/tools}}"
P="$here/acl2/atc-scalar"; B="$here/build/scalar"; mkdir -p "$B"
awk '/^int adjustPoint/{p=1} p{print} p&&/^}/{exit}' "$TOOLS_DIR/emil/adjust.c" \
  | sed 's/^int adjustPoint/int emil_adjustPoint/' > "$B/emil_adjust.c"
F="-std=c99 -Wall -Wextra -Wpedantic -Wconversion -O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all"
for cc in gcc clang; do
  $cc $F -I"$P" "$P/adjust_scalar.c" "$P/adjust_wrapper.c" "$B/emil_adjust.c" "$here/tests/m0/scalar_smoke.c" -o "$B/smoke-$cc" 2> "$B/$cc.warnings"
  echo "== $cc: $(grep -c 'warning:' "$B/$cc.warnings" || true) warnings"
  "$B/smoke-$cc"
done
