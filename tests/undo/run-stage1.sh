#!/usr/bin/env bash
# All Stage 1 differential runs against one driver.
# Usage: tests/undo/run-stage1.sh DRIVER OUT_DIR [VALID_SEEDS] [VALID_STEPS] [HOSTILE_SEEDS]
here="$(cd "$(dirname "$0")/../.." && pwd)"
driver="$1"; out="$2"; vs="${3:-300}"; vn="${4:-5000}"; hs="${5:-100}"
mkdir -p "$out"
"$here/scripts/undo-diff.sh" "$driver" valid 1 "$vs" "$vn" "$out/w-valid" "$out/valid.log"
for c in xpast ypast rev1 rev2 spast inspast lie extend; do
  "$here/scripts/undo-diff.sh" "$driver" "$c" 1 "$hs" 2000 "$out/w-$c" "$out/$c.log"
done
