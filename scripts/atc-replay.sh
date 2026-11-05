#!/usr/bin/env bash
# Re-prove ATC's generated theorems with ATC and every trust tag removed.
# Usage: scripts/atc-replay.sh BOOK.lisp "fn1 fn2 ..."   (BOOK must be certified)
#
# 1. Dump ATC's expanded events as text.
# 2. Build a replay book: same functions, same generated proofs, no ATC, no
#    file-writing event, no :ttags. See scripts/atc-replay.py.
# 3. Certify it from scratch and audit its whole include tree with --strict.
# 4. Check that the program constant, functions and -CORRECT theorems are identical
#    in the ATC world and the replay world.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
export TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
ACL2="$TOOLS_DIR/acl2/saved_acl2"; export ACL2 ACL2_CUSTOMIZATION=NONE
src="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; name="$(basename "$1" .lisp)"; fns="$2"
W="$here/build/replay/$name"; rm -rf "$W"; mkdir -p "$W/dump"
cp "$src" "$W/dump/$name.lisp"
INC="kestrel/c/atc/symbolic-execution-rules/top kestrel/c/atc/shallow-embedding kestrel/c/atc/function-and-loop-generation kestrel/event-macros/proof-preparation kestrel/event-macros/cw-event tools/trivial-ancestors-check std/system/theorem-symbolp misc/install-not-normalized"

( cd "$W/dump"
  cat > a.lsp <<LSP
(include-book "kestrel/c/portcullis" :dir :system)
(set-write-acl2x t state)
(certify-book "$name" ? t :ttags :all :acl2x t)
LSP
  "$ACL2" < a.lsp > a.out 2>&1
  [ -f "$name.acl2x" ] || { echo "no acl2x for $name"; tail -5 a.out; exit 1; }
  cat > b.lsp <<LSP
(include-book "kestrel/c/portcullis" :dir :system)
(include-book "kestrel/c/atc/atc" :dir :system :ttags :all)
(set-serialize-character nil state)
(mv-let (ch state) (open-input-channel "$name.acl2x" :object state)
  (mv-let (eof v state) (read-object ch state)
    (declare (ignore eof))
    (pprogn (close-input-channel ch state)
      (mv-let (o state) (open-output-channel "events.txt" :object state)
        (pprogn (print-object\$ v o state) (close-output-channel o state))))))
LSP
  "$ACL2" < b.lsp > b.out 2>&1 )

cat > "$W/cert.acl2" <<'CERT'
(include-book "kestrel/c/portcullis" :dir :system)

; cert-flags: ? t :useless-runes nil
CERT
"$here/scripts/atc-replay.py" "$W/dump/events.txt" "$src" "$W/$name-replay.lisp" $INC
if [ -n "${TAMPER:-}" ]; then sed -i "$TAMPER" "$W/$name-replay.lisp"; fi
start=$SECONDS
( cd "$W" && "$TOOLS_DIR/acl2/books/build/cert.pl" --acl2 "$ACL2" "$name-replay.lisp" >/dev/null 2>&1 ) \
  || { echo "REPLAY FAILED: $name"; grep -m3 -A4 'ACL2 Error' "$W/$name-replay.cert.out" | cut -c1-140; exit 1; }
rm -f "$W/Makefile-tmp"
echo "replay certified in $((SECONDS-start))s"
"$here/scripts/cert-audit.py" "$W/$name-replay.lisp" --strict

# Compare the statements in the two worlds
forms='(defun dump-loop (names o state)
  (declare (xargs :mode :program :stobjs state))
  (if (endp names) state
    (pprogn (print-object$ (list (car names)
                                 (getpropc (car names) (quote theorem) nil (w state))
                                 (getpropc (car names) (quote unnormalized-body) nil (w state))
                                 (getpropc (car names) (quote const) nil (w state)))
                           o state)
            (dump-loop (cdr names) o state))))'
syms="c::*program*"
for f in $fns; do syms="$syms |$f| c::|*PROGRAM*-$f-CORRECT|"; done
for side in atc replay; do
  if [ $side = atc ]; then bk="${src%.lisp}"; else bk="$W/$name-replay"; fi
  cat > "$W/cmp-$side.lsp" <<LSP
(include-book "$bk" :ttags :all)
(set-serialize-character nil state)
$forms
(mv-let (o state) (open-output-channel "$W/statements-$side.txt" :object state)
  (pprogn (dump-loop (quote ($syms)) o state) (close-output-channel o state)))
LSP
  "$ACL2" < "$W/cmp-$side.lsp" > "$W/cmp-$side.out" 2>&1
done
n=$(grep -c . "$W/statements-replay.txt" || true)
python3 - "$W" "$fns" <<'PY'
import sys
W, fns = sys.argv[1], sys.argv[2].split()
a = open(f"{W}/statements-atc.txt").read(); b = open(f"{W}/statements-replay.txt").read()
if not a.strip() or a != b:
    sys.exit("STATEMENTS DIFFER between ATC and replay worlds")
need = len(fns)*2 + 1
empty = a.count("(NIL NIL NIL)") + a.count("NIL NIL NIL)")
if empty:
    sys.exit(f"STATEMENT MISSING: {empty} empty entries of {need}")
print(f"statements identical in both worlds: {need} items")
PY
echo "REPLAY OK: $name"
