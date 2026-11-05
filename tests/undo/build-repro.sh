#!/usr/bin/env bash
# Build repro_paths.c against a tree that tests/undo/build.sh has already built.
# Usage: tests/undo/build-repro.sh BUILD_DIR
here="$(cd "$(dirname "$0")" && pwd)"; out="$1"; cd "$out/src" || exit 1
objs=$(ls *.o | grep -vE '^(main|terminal)\.o$')
cc -std=c99 -D_DEFAULT_SOURCE -g -O1 -fsanitize=address,undefined -fno-sanitize-recover=all -w -I. -Itests -x c "$here/repro_paths.c" -x none $objs stubs.o.tmp -pie -lm -o "$out/repro_paths"
