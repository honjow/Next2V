#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/sync-signing-materials.sh [SOURCE_DIR] [--dest DEST_DIR]

Copy local, gitignored HarmonyOS debug signing materials.

  SOURCE_DIR   default: /home/gamer/git/V2Next/scripts
  --dest DIR   default: the directory containing this script (i.e. the
               worktree's scripts/ when called as
               $worktree/scripts/sync-signing-materials.sh). Pass --dest
               explicitly when calling the main-repo copy from another
               worktree.

Files copied:
- xiaobai.p12
- xiaobai.csr
- next2v-debug.cer
- next2v-debug.p7b

This script does not print secrets and does not call Huawei/AGC APIs.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR=""
DEST_DIR="$SCRIPT_DIR"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST_DIR="$2"; shift 2 ;;
    --dest=*) DEST_DIR="${1#--dest=}"; shift ;;
    *) if [[ -z "$SOURCE_DIR" ]]; then SOURCE_DIR="$1"; shift; else echo "unknown arg: $1" >&2; exit 2; fi ;;
  esac
done
SOURCE_DIR="${SOURCE_DIR:-/home/gamer/git/V2Next/scripts}"

if [[ ! -d "$DEST_DIR" ]]; then
  echo "ERROR: dest directory not found: $DEST_DIR" >&2
  exit 1
fi

FILES=(xiaobai.p12 xiaobai.csr next2v-debug.cer next2v-debug.p7b)

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

for file in "${FILES[@]}"; do
  if [[ ! -f "$SOURCE_DIR/$file" ]]; then
    echo "ERROR: missing signing material: $SOURCE_DIR/$file" >&2
    exit 1
  fi
done

for file in "${FILES[@]}"; do
  install -m 600 "$SOURCE_DIR/$file" "$DEST_DIR/$file"
  bytes=$(wc -c < "$DEST_DIR/$file" | tr -d ' ')
  echo "copied $(basename "$DEST_DIR")/$file (${bytes} bytes)"
done

echo "signing materials ready in $DEST_DIR"
