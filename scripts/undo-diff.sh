#!/usr/bin/env bash
# Differential test: emil's C against the ACL2 model.
# Usage: scripts/undo-diff.sh DRIVER MODE FIRST_SEED LAST_SEED STEPS WORK_DIR OUT_LOG
# WORK_DIR holds one batch of traces at a time, reused under fixed names, so it
# stays small and nothing needs deleting. Failing seeds' operations are kept in
# WORK_DIR/failed. Test evidence only.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
driver="$1"; mode="$2"; first="$3"; last="$4"; steps="$5"; work="$6"; log="$7"
TOOLS_DIR="${TOOLS_DIR:-/root/tools-clean}"
ACL2="$TOOLS_DIR/acl2/saved_acl2"
BATCH="${BATCH:-20}"
mkdir -p "$work/failed"
: > "$log"
s=$first
while [ "$s" -le "$last" ]; do
  e=$(( s + BATCH - 1 )); [ "$e" -gt "$last" ] && e=$last
  files=""; n=0
  for i in $(seq "$s" "$e"); do
    ASAN_OPTIONS=detect_leaks=0 "$driver" --seed "$i" --steps "$steps" --mode "$mode" \
      --ops-out "$work/$n.ops" >"$work/$n.trace" 2>"$work/$n.err"
    rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "CRASHINFO $i $mode rc=$rc: $(grep -m1 -E 'ERROR|runtime error|die:|Assert' "$work/$n.err" | cut -c1-160)" >>"$log"
      echo "LASTOP $i $(tail -1 "$work/$n.ops")" >>"$log"
    fi
    cp "$work/$n.ops" "$work/failed/$mode-$i.ops"
    files="$files \"$work/$n.trace\""; n=$(( n + 1 ))
  done
  cat > "$work/run.lsp" <<LSP
(set-inhibit-output-lst '(prove proof-tree event summary warning warning! observation))
(ld "$here/acl2/undo/diff/check.lsp" :ld-pre-eval-print nil :ld-post-eval-print nil :ld-verbose nil)
(check-files '($files) state)
(good-bye 0)
LSP
  "$ACL2" < "$work/run.lsp" 2>&1 | sed -E 's/^ACL2 [!p]*>//' | grep -E -A6 '^(DIFF|PROP|HIST|RESULT|NOFILE|BADHEADER)|ACL2 Error|HARD ACL2' \
     | grep -vE '^--$' | grep -vE '^(ACL2 !?>|$)' >> "$log"
  s=$(( e + 1 ))
done
echo "done" >> "$log"
