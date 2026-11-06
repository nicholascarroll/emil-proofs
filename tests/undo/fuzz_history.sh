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
# Lines ending in a truncated UTF-8 sequence, which the fuzzer's own text lacks.
s=s.replace('	"(defun foo (x) (+ x 1))",','	"(defun foo (x) (+ x 1))",\n	"a\\xC3",\n	"b\\xF0",\n	"\\xE2\\x82",\n	"x\\xF0\\x9F",\n	"\\xC3",',1)
open(p,'w').write(s)
PY
# Log every invalid range and replay mismatch the refactored code reports.
if grep -q 'Invalid edit range' "$work/src/mutate.c"; then
  python3 - "$work/src" <<'PY'
import sys
d=sys.argv[1]
for f,msg in (('mutate.c','INVALID-RANGE'),('undo.c','REPLAY-MISMATCH')):
    p=d+'/'+f; s=open(p).read()
    s=s.replace('#include <limits.h>','#include <limits.h>\n#include <stdio.h>\n#include <fcntl.h>\n#include <unistd.h>\nvoid __sanitizer_print_stack_trace(void);',1)
    needle='setStatusMessage("Invalid edit range; nothing changed");' if f=='mutate.c' else 'setStatusMessage("Undo history doesn\'t match the text; "'
    assert needle in s
    log='{ const char *lg = getenv("REFUSAL_LOG"); FILE *lf = lg ? fopen(lg, "a") : NULL; if (lf) { fprintf(lf, "%s %s\\n", "'+msg+'", buf == E.minibuf ? "minibuf" : buf->special_buffer ? "special" : "file"); fclose(lf); } if (lg && getenv("REFUSAL_STACK")) { int fd = open(lg, O_WRONLY | O_APPEND); int sv = dup(2); dup2(fd, 2); __sanitizer_print_stack_trace(); dup2(sv, 2); close(sv); close(fd); } } '
    s=s.replace(needle,log+needle)
    open(p,'w').write(s)
PY
fi
touch "$work/refusals.log"
chmod -R a+rwX "$work"
cd "$work/src"
setpriv --reuid=65534 --regid=65534 --clear-groups env TMPDIR="$work" FUZZ_WORK="$work/fz" REFUSAL_LOG="$work/refusals.log" sh tests/fuzz_keys.sh "$first" "$count"
