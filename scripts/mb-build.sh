#!/bin/bash
# Spiegelt das Projekt aufs MacBook und baut es dort für den Simulator.
# Aufruf: scripts/mb-build.sh [Zielordner auf dem MacBook, Standard: ~/Developer/Yolk]
set -euo pipefail
HOST="${YOLK_HOST:-macbook}"
DEST="${1:-Developer/Yolk}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rsync -a --delete --exclude .git --exclude build --exclude DerivedData --exclude xcuserdata "$ROOT/" "$HOST:$DEST/"
ssh -o BatchMode=yes "$HOST" "cd ~/$DEST && xcodebuild -project Yolk.xcodeproj -scheme Yolk -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E 'error:|warning: .*\.swift|BUILD (SUCCEEDED|FAILED)|\*\* ' | head -80"
