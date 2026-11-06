#!/usr/bin/env bash
# Key fuzz that records every invalid UTF-8 row in every buffer, and every file write.
# Usage: tests/undo/fuzz_utf8.sh EMIL_REPO COMMIT WORK_DIR FIRST COUNT stock|truncated
# "stock" keeps the fuzzer's own text. "truncated" adds the lines that fuzz_history.sh
# adds. WORK_DIR must not exist. Works on an export, as an unprivileged user.
# Output: WORK_DIR/utf8.log (see utf8_check.c) and stdout from the fuzzer.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$1"; commit="$2"; work="$3"; first="$4"; count="$5"; text="$6"
mkdir -p "$(dirname "$work")"; mkdir "$work"; mkdir "$work/src"
git -C "$repo" archive "$commit" | tar -x -C "$work/src"
cp "$here/utf8_check.c" "$work/src/tests/utf8_check.inc"
python3 - "$work/src" "$text" <<'PY'
import sys
d,text=sys.argv[1:3]
p=d+'/tests/fuzz_keys.c'; s=open(p).read()
a='static void runSequence(uint32_t seed) {'
assert a in s
s=s.replace(a,'#include "utf8_check.inc"\n\n'+a,1)
a='	kpos = 0;\n	exhausted_reads = 0;\n	for (;;) {\n		refreshScreen();'
assert a in s
s=s.replace(a,'	kpos = 0;\n	exhausted_reads = 0;\n	utf8CheckStart(seed);\n	for (;;) {\n		refreshScreen();',1)
a='processKeypress(cmd);'
assert a in s
s=s.replace(a,'processKeypress(cmd); utf8CheckAll(key);',1)
a='	fprintf(stderr, "LEAD at key %d: %s\\n", kpos, what);'
assert a in s
s=s.replace(a,a+'\n	utf8LeadSeen(kpos, what);',1)
a='static int lead_reported;'
assert a in s
s=s.replace(a,'void utf8LeadSeen(int k, const char *what);\n'+a,1)
if text=='truncated':
    a='	"(defun foo (x) (+ x 1))",'
    assert a in s
    s=s.replace(a,a+'\n	"a\\xC3",\n	"b\\xF0",\n	"\\xE2\\x82",\n	"x\\xF0\\x9F",\n	"\\xC3",',1)
else:
    assert text=='stock'
a='		runSequence(seed);\n		_exit(lead_reported ? 4 : 0);'
assert a in s
s=s.replace(a,'		runSequence(seed);\n		utf8End(seed);\n		_exit(lead_reported ? 4 : 0);',1)
open(p,'w').write(s)
# Log every write that reaches a file, and every refusal at the save check.
p=d+'/fileio.c'; s=open(p).read()
hook='''
#include <fcntl.h>
static void utf8SaveLog(const char *what, const char *path, const void *buf, size_t len) {
	const char *lg = getenv("UTF8_LOG");
	if (!lg) return;
	char line[600];
	int n = snprintf(line, sizeof(line), "%s valid=%d len=%zu path=%.200s\\n", what,
		buf ? utf8_validate((const uint8_t *)buf, (int)len) : -1, len, path ? path : "-");
	int fd = open(lg, O_WRONLY | O_APPEND | O_CREAT, 0666);
	if (fd >= 0) { if (write(fd, line, (size_t)n) < 0) {} close(fd); }
}
'''
a='static int checkUTF8Validity(struct buffer *bufr) {'
assert a in s
s=s.replace(a,hook+a,1)
a='	if (writeAll(fd, buf, len) == -1)'
assert a in s
s=s.replace(a,'	utf8SaveLog("WRITE", path, buf, len);\n'+a,1)
a='		setStatusMessage("Save failed: buffer contains invalid UTF-8");'
assert a in s
s=s.replace(a,'		utf8SaveLog("REFUSED", E.buf->filename, NULL, 0);\n'+a,1)
open(p,'w').write(s)
PY
touch "$work/utf8.log"
chmod -R a+rwX "$work"
cd "$work/src"
setpriv --reuid=65534 --regid=65534 --clear-groups env TMPDIR="$work" FUZZ_WORK="$work/fz" \
  UTF8_LOG="$work/utf8.log" sh tests/fuzz_keys.sh "$first" "$count"
