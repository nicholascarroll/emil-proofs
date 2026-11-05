#!/usr/bin/env bash
# Certify this repo's books from clean, then enforce the trust rules.
# Usage: scripts/certify.sh [TOOLS_DIR]
#
#   STRICT_DIRS (spec and claim books): any trust tag, skipped proof, axiom or
#       fast-cert use makes this script fail.
#   ATC_DIRS (books that run ATC): owner-approved 2026-11-06. Only the tags in
#       scripts/atc-allowed-ttags.txt are permitted. Skipped proofs, axioms,
#       other tags and fast-cert still make this script fail.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${1:-${TOOLS_DIR:-$HOME/tools}}"
export TOOLS_DIR
export ACL2="$TOOLS_DIR/acl2/saved_acl2"
export ACL2_SYSTEM_BOOKS="$TOOLS_DIR/acl2/books"
CERT="$TOOLS_DIR/acl2/books/build/cert.pl"
JOBS="${JOBS:-2}"
STRICT_DIRS=(acl2/trivial)
ATC_DIRS=(acl2/atc-proto acl2/atc-scalar)
ALLOWED="$here/scripts/atc-allowed-ttags.txt"
cd "$here" || exit 1
export ACL2_CUSTOMIZATION=NONE

find acl2 \( -name '*.cert' -o -name '*.port' -o -name '*.out' -o -name '*.fasl' \
   -o -name '*.time' -o -name '*.date' -o -name '*.lx64fsl' \) -delete

fail=0
books=$(for d in "${STRICT_DIRS[@]}" "${ATC_DIRS[@]}"; do find "$d" -name '*.lisp' 2>/dev/null; done)
"$CERT" -j "$JOBS" --acl2 "$ACL2" $books || { echo "CERTIFICATION FAILED"; exit 1; }

if [ -n "${ACL2_FAST_CERT:-}" ] || [ -n "${ACL2_PCERT:-}" ]; then
  echo "fast-cert or pcert environment is set"; fail=1
fi

# Source-level checks on our own books
for d in "${STRICT_DIRS[@]}"; do
  if grep -rnEi 'skip-proofs|defaxiom|defttag|remove-untouchable|fast-cert|:ttags|set-skip|include-raw|progn!' "$d" --include='*.lisp' --include='*.acl2'; then
    echo "FORBIDDEN CONSTRUCT in $d"; fail=1
  fi
done
for d in "${ATC_DIRS[@]}"; do
  if grep -rnEi 'skip-proofs|defaxiom|defttag|remove-untouchable|fast-cert|set-skip|include-raw|progn!' "$d" --include='*.lisp' --include='*.acl2'; then
    echo "FORBIDDEN CONSTRUCT in $d"; fail=1
  fi
done

# Certificate-level checks: ACL2 loads each book and reports its whole include tree
checked=0
for d in "${STRICT_DIRS[@]}"; do
  for f in $(find "$d" -name '*.lisp'); do
    scripts/cert-audit.py "$f" --strict || fail=1
    checked=$((checked+1))
  done
done
for d in "${ATC_DIRS[@]}"; do
  for f in $(find "$d" -name '*.lisp'); do
    scripts/cert-audit.py "$f" --allow "$ALLOWED" || fail=1
    checked=$((checked+1))
  done
done
[ "$checked" -gt 0 ] || { echo "NO CERTIFICATES CHECKED"; fail=1; }
[ "$fail" = 0 ] && echo "CERTIFY OK ($checked books)" || { echo "CERTIFY FAILED: rules violated"; exit 1; }
