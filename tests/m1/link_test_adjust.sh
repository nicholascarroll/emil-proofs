#!/bin/sh
# Link emil's tests/test_adjust.c with the objects already built in a copy of emil.
# Usage: link_test_adjust.sh COPY_DIR OUTPUT. Uses whatever adjust.o is in COPY_DIR.
set -e
cd "$1"
OBJ="decoder.o unicode.o buffer.o region.o undo.o transform.o find.o pipe.o register.o fileio.o display.o keymap.o edit.o prompt.o util.o completion.o history.o base64.o abuf.o window.o ctags.o adjust.o mutate.o wrap.o motion.o dbuf.o emil_subprocess.o palette.o backup.o message.o tests/stubs.o"
cc -std=c99 -D_DEFAULT_SOURCE -O2 -w -I. -Itests tests/test_adjust.c $OBJ -o "$2"
