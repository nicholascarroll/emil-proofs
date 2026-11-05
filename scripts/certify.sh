#!/usr/bin/env bash
# Certify this repo's books from clean, then enforce the no-trust rules.
# Usage: scripts/certify.sh [TOOLS_DIR]
#
#   acl2/trivial and (later) claim books: STRICT. Any trust tag, skipped proof,
#       axiom, or fast-cert use makes this script fail.
#   acl2/atc-proto: QUARANTINED while the ATC trust-tag question is with the
#       owner. It backs no claim. Its tags are reported, not hidden.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${1:-${TOOLS_DIR:-$HOME/tools}}"
export ACL2="$TOOLS_DIR/acl2/saved_acl2"
export ACL2_SYSTEM_BOOKS="$TOOLS_DIR/acl2/books"
CERT="$TOOLS_DIR/acl2/books/build/cert.pl"
JOBS="${JOBS:-2}"
STRICT_DIRS=(acl2/trivial)
QUARANTINE_DIRS=(acl2/atc-proto)
cd "$here" || exit 1
unset ACL2_CUSTOMIZATION
export ACL2_CUSTOMIZATION=NONE

find acl2 \( -name '*.cert' -o -name '*.port' -o -name '*.out' -o -name '*.fasl' \
   -o -name '*.time' -o -name '*.date' -o -name '*.lx64fsl' \) -delete

fail=0
books=$(for d in "${STRICT_DIRS[@]}" "${QUARANTINE_DIRS[@]}"; do find "$d" -name '*.lisp' 2>/dev/null; done)
"$CERT" -j "$JOBS" --acl2 "$ACL2" $books || { echo "CERTIFICATION FAILED"; exit 1; }

# Source-level check in the strict directories
for d in "${STRICT_DIRS[@]}"; do
  if grep -rnEi 'skip-proofs|defaxiom|defttag|remove-untouchable|fast-cert|:ttags|set-skip|include-raw|progn!' "$d" --include='*.lisp' --include='*.acl2'; then
    echo "FORBIDDEN CONSTRUCT in $d"; fail=1
  fi
done
if [ -n "${ACL2_FAST_CERT:-}" ] || [ -n "${ACL2_PCERT:-}" ]; then echo "fast-cert or pcert environment is set"; fail=1; fi

# Certificate-level check: annotations are transitive over included books
annot() { "$here/scripts/cert-annotations.py" "$1"; }
for d in "${STRICT_DIRS[@]}"; do
  for c in $(find "$d" -name '*.cert'); do
    annot "$c" --strict || fail=1
  done
done
for d in "${QUARANTINE_DIRS[@]}"; do
  for c in $(find "$d" -name '*.cert'); do
    echo "QUARANTINED (backs no claim):"; annot "$c" || true
  done
done
[ "$fail" = 0 ] && echo "CERTIFY OK" || { echo "CERTIFY FAILED: rules violated"; exit 1; }
