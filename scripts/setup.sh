#!/usr/bin/env bash
# Rebuild the toolchain from pinned versions. Idempotent.
# Usage: scripts/setup.sh [TOOLS_DIR]   (default: $HOME/tools)
# Result: $TOOLS_DIR/acl2/saved_acl2 and a read-only emil clone at $TOOLS_DIR/emil.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/versions.env"
TOOLS_DIR="${1:-${TOOLS_DIR:-$HOME/tools}}"
mkdir -p "$TOOLS_DIR"

# 1. SBCL, exact package version
have="$(dpkg-query -W -f='${Version}' sbcl 2>/dev/null || true)"
if [ "$have" != "$SBCL_APT_VERSION" ]; then
  apt-get update -qq
  apt-get install -y -qq "sbcl=$SBCL_APT_VERSION"
fi
sbcl --version

# 2. Fetch one exact commit at depth 1; refuse anything else
fetch_pinned() { # repo commit dir
  local repo="$1" commit="$2" dir="$3"
  if [ ! -d "$dir/.git" ]; then
    git init -q "$dir"
    git -C "$dir" remote add origin "$repo"
  fi
  if [ "$(git -C "$dir" rev-parse -q --verify HEAD || true)" != "$commit" ]; then
    git -C "$dir" fetch -q --depth 1 origin "$commit"
    git -C "$dir" checkout -q --detach FETCH_HEAD
  fi
  [ "$(git -C "$dir" rev-parse HEAD)" = "$commit" ] || { echo "pin mismatch: $dir" >&2; exit 1; }
}
fetch_pinned "$ACL2_REPO" "$ACL2_COMMIT" "$TOOLS_DIR/acl2"
fetch_pinned "$EMIL_REPO" "$EMIL_COMMIT" "$TOOLS_DIR/emil"
git -C "$TOOLS_DIR/emil" remote set-url --push origin DISABLED  # emil is read-only here

# 3. Build ACL2 on SBCL
if [ ! -x "$TOOLS_DIR/acl2/saved_acl2" ]; then
  make -C "$TOOLS_DIR/acl2" LISP=sbcl
fi
[ -x "$TOOLS_DIR/acl2/saved_acl2" ] || { echo "ACL2 build failed" >&2; exit 1; }
echo "SETUP OK: ACL2 $(git -C "$TOOLS_DIR/acl2" rev-parse --short HEAD), emil $(git -C "$TOOLS_DIR/emil" rev-parse --short HEAD), TOOLS_DIR=$TOOLS_DIR"
