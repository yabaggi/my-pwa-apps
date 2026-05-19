#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# sync.sh  —  Sync VideoFlow content → GitHub Pages (TutorialMaker) repo
#
# Logic:
#   videos.json         → always synced
#   snaps/<id>/         → synced for every video where snapped=true
#   dl-<id>.mp4         → synced ONLY for videos where downloaded=true
#                          AND snapped=false  (user still needs to snap manually)
#                          Once a video gets snapped, the mp4 is removed from
#                          the GitHub repo to keep it lean.
#
# Usage:
#   ./sync.sh            # normal sync
#   ./sync.sh --dry-run  # preview only, no files changed, no git push
#
# Place this file in ~/pwaApps/craftut/ and run from there.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
SRC="$HOME/pwaApps/craftut"
DST="$HOME/githubreps/my-pwa-apps/craftut"
GITDST="$HOME/githubreps/my-pwa-apps"
BRANCH="main"
COMMIT_MSG="sync: $(date '+%Y-%m-%d %H:%M')"

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# ── HELPERS ───────────────────────────────────────────────────────────────────
log()  { echo "  $1"; }
bold() { echo ""; echo "▸ $1"; }
run()  { if $DRY_RUN; then echo "  [dry] $*"; else "$@"; fi; }

command -v rsync >/dev/null && USE_RSYNC=true || USE_RSYNC=false
command -v jq    >/dev/null || { echo "✗ jq is required (pkg install jq)"; exit 1; }

# ── PRE-FLIGHT ────────────────────────────────────────────────────────────────
bold "Pre-flight"
[ -d "$SRC" ] || { echo "✗ Source not found: $SRC"; exit 1; }
[ -d "$DST" ] || { echo "✗ Destination not found: $DST"; exit 1; }
[ -f "$SRC/videos.json" ] || { echo "✗ videos.json not found in $SRC"; exit 1; }
log "Source  : $SRC"
log "Dest    : $DST"
log "Dry run : $DRY_RUN"
log "rsync   : $USE_RSYNC"

# ── READ videos.json ONCE ─────────────────────────────────────────────────────
VIDEOS_JSON="$SRC/videos.json"

# IDs of videos that are downloaded (have a local mp4)
DOWNLOADED_IDS=$(jq -r '.[] | select(.downloaded==true) | .id' "$VIDEOS_JSON")

# IDs of videos that are snapped
SNAPPED_IDS=$(jq -r '.[] | select(.snapped==true) | .id' "$VIDEOS_JSON")

# IDs that are downloaded but NOT yet snapped → need mp4 in repo
UNSNAPPED_IDS=$(jq -r '.[] | select(.downloaded==true and .snapped==false) | .id' "$VIDEOS_JSON")

# ── SYNC videos.json ──────────────────────────────────────────────────────────
bold "Syncing videos.json"
if [ -f "$DST/videos.json" ] && diff -q "$VIDEOS_JSON" "$DST/videos.json" >/dev/null 2>&1; then
  log "Unchanged — skip"
else
  log "Copying videos.json …"
  run cp "$VIDEOS_JSON" "$DST/videos.json"
fi

# ── SYNC snaps/ ───────────────────────────────────────────────────────────────
bold "Syncing snaps/ (snapped videos only)"

if [ -z "$SNAPPED_IDS" ]; then
  log "No snapped videos yet — skip"
else
  run mkdir -p "$DST/snaps"
  for ID in $SNAPPED_IDS; do
    SRC_DIR="$SRC/snaps/$ID"
    DST_DIR="$DST/snaps/$ID"
    if [ ! -d "$SRC_DIR" ]; then
      log "snaps/$ID — folder missing in source, skip"
      continue
    fi
    FRAME_COUNT=$(ls "$SRC_DIR"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
    if $USE_RSYNC; then
      run rsync -a --delete \
        --include="*.jpg" --exclude="*" \
        "$SRC_DIR/" "$DST_DIR/"
    else
      run mkdir -p "$DST_DIR"
      run cp "$SRC_DIR/"*.jpg "$DST_DIR/"
    fi
    log "snaps/$ID — $FRAME_COUNT frames ✓"
  done
fi

# ── REMOVE snaps/ for videos that no longer exist ─────────────────────────────
# (cleanup orphan snap folders if a video was deleted from videos.json)
if [ -d "$DST/snaps" ]; then
  for DST_DIR in "$DST/snaps"/*/; do
    [ -d "$DST_DIR" ] || continue
    ID=$(basename "$DST_DIR")
    if ! echo "$SNAPPED_IDS" | grep -qx "$ID"; then
      log "snaps/$ID — not in snapped list, removing from repo …"
      run rm -rf "$DST_DIR"
    fi
  done
fi

# ── SYNC dl-*.mp4 for UNSNAPPED videos only ───────────────────────────────────
bold "Syncing dl-*.mp4 (downloaded + not yet snapped)"

if [ -z "$UNSNAPPED_IDS" ]; then
  log "All downloaded videos are already snapped — no mp4s needed in repo"
else
  for ID in $UNSNAPPED_IDS; do
    SRC_MP4="$SRC/dl-$ID.mp4"
    DST_MP4="$DST/dl-$ID.mp4"
    if [ ! -f "$SRC_MP4" ]; then
      log "dl-$ID.mp4 — not found in source, skip"
      continue
    fi
    if [ -f "$DST_MP4" ] && diff -q "$SRC_MP4" "$DST_MP4" >/dev/null 2>&1; then
      log "dl-$ID.mp4 — unchanged, skip"
    else
      SIZE=$(du -h "$SRC_MP4" | cut -f1)
      log "dl-$ID.mp4 — copying ($SIZE) …"
      run cp "$SRC_MP4" "$DST_MP4"
    fi
  done
fi

# ── REMOVE mp4s that are now snapped (no longer needed in repo) ───────────────
bold "Cleaning up mp4s that are now snapped"

REMOVED_MP4=0
for DST_MP4 in "$DST"/dl-*.mp4; do
  [ -f "$DST_MP4" ] || continue
  FNAME=$(basename "$DST_MP4")
  ID="${FNAME#dl-}"; ID="${ID%.mp4}"
  # If this ID is now snapped → remove the mp4 from the repo
  if echo "$SNAPPED_IDS" | grep -qx "$ID"; then
    log "$FNAME — now snapped, removing from repo …"
    run rm "$DST_MP4"
    REMOVED_MP4=$((REMOVED_MP4 + 1))
  fi
done
[ "$REMOVED_MP4" -eq 0 ] && log "Nothing to remove"

# ── GIT PUSH ──────────────────────────────────────────────────────────────────
bold "Git push → $BRANCH"
cd "$GITDST"

if $DRY_RUN; then
  log "[dry] would run: git add -A && git commit && git push"
else
  git add -A
  if git diff --cached --quiet; then
    log "Nothing changed in git — no commit needed"
  else
    CHANGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
    log "Committing $CHANGED changed file(s) …"
    git commit -m "$COMMIT_MSG"
    git push origin "$BRANCH"
    log "Pushed ✓"
  fi
fi

# ── SUMMARY ───────────────────────────────────────────────────────────────────
bold "Summary"
TOTAL=$(jq '. | length' "$VIDEOS_JSON")
DL=$(jq '[.[] | select(.downloaded==true)] | length' "$VIDEOS_JSON")
SNAPPED=$(jq '[.[] | select(.snapped==true)] | length' "$VIDEOS_JSON")
UNSNAPPED=$(jq '[.[] | select(.downloaded==true and .snapped==false)] | length' "$VIDEOS_JSON")

log "Total videos : $TOTAL"
log "Downloaded   : $DL"
log "Snapped      : $SNAPPED  ← only snaps/ folder in repo"
log "Unsnapped    : $UNSNAPPED  ← mp4 included in repo for manual snapping"
$DRY_RUN && log "(dry run — nothing was changed)"
echo ""


