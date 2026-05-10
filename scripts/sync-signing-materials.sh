#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/sync-signing-materials.sh [SOURCE_DIR]

Copy local, gitignored HarmonyOS debug signing materials into this worktree.
Default SOURCE_DIR: /home/gamer/git/V2Next/scripts

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
SOURCE_DIR="${1:-/home/gamer/git/V2Next/scripts}"
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
  install -m 600 "$SOURCE_DIR/$file" "$SCRIPT_DIR/$file"
  bytes=$(wc -c < "$SCRIPT_DIR/$file" | tr -d ' ')
  echo "copied scripts/$file (${bytes} bytes)"
done

echo "signing materials ready in $SCRIPT_DIR"
