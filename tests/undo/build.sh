#!/usr/bin/env bash
# Build the differential driver against an emil commit, under ASan and UBSan.
# Usage: tests/undo/build.sh EMIL_REPO COMMIT OUT_DIR
# OUT_DIR must not exist yet. The commit is exported into it, so the working copy
# is left alone.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$1"; commit="$2"; out="$3"
mkdir -p "$(dirname "$out")"
mkdir "$out"; mkdir "$out/src"
git -C "$repo" archive "$commit" | tar -x -C "$out/src"
git -C "$repo" rev-parse "$commit" > "$out/commit"
cd "$out/src"
SAN="-g -O1 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer"
make -j2 CFLAGS="$SAN -fPIE ${EXTRA_CFLAGS:-}" LDFLAGS="-fsanitize=address,undefined -pie ${EXTRA_CFLAGS:-}" emil >make.log 2>&1 \
  || { tail -20 make.log; exit 1; }
api=""
grep -q 'old_text' mutate.h && api="-DEMIL_OLD_API"
grep -q 'enum mutateResult' mutate.h && api="$api -DEMIL_RESULT_API"
objs=$(ls *.o | grep -vE '^(main|terminal)\.o$')
cc -std=c99 -D_DEFAULT_SOURCE $SAN $api ${EXTRA_CFLAGS:-} -w -I. -Itests -c tests/stubs.c -o stubs.o.tmp
cc -std=c99 -D_DEFAULT_SOURCE $SAN $api ${EXTRA_CFLAGS:-} -w -I. -Itests -x c "$here/driver.c" -x none $objs stubs.o.tmp \
   -fsanitize=address,undefined -pie ${EXTRA_CFLAGS:-} -lm -o "$out/driver"
echo "built $out/driver from $(cat "$out/commit") api=${api:-new}"
