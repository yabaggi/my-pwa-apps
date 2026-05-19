#!/bin/bash
# verify-sync.sh — Verify sync state between pwaApps/craftut and GitHub Pages repo
# Shows what's in sync, what's missing, and what's expected to differ
#
# Usage:
#   ./verify-sync.sh          # full report
#   ./verify-sync.sh --quiet  # only show problems

SRC="$HOME/pwaApps/craftut"
DST="$HOME/githubreps/my-pwa-apps/craftut"
QUIET=false
[ "${1:-}" = "--quiet" ] && QUIET=true

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }
err()  { echo -e "  ${RED}✗${NC} $*"; }
info() { $QUIET || echo -e "  ${DIM}·${NC} $*"; }
bold() { echo -e "\n${BOLD}▸ $*${NC}"; }
sep()  { $QUIET || echo -e "${DIM}────────────────────────────────────────────${NC}"; }

ISSUES=0
issue() { err "$*"; ISSUES=$((ISSUES + 1)); }

# ── Pre-flight ────────────────────────────────────────────────────────────────
bold "Paths"
info "Source : $SRC"
info "Dest   : $DST"

[ -d "$SRC" ] || { err "Source not found: $SRC"; exit 1; }
[ -d "$DST" ] || { err "Dest not found: $DST";   exit 1; }
command -v jq >/dev/null || { err "jq required (pkg install jq)"; exit 1; }

SRC_JSON="$SRC/videos.json"
DST_JSON="$DST/videos.json"

[ -f "$SRC_JSON" ] || { err "videos.json missing in source"; exit 1; }
[ -f "$DST_JSON" ] || { issue "videos.json MISSING in dest — run ./sync.sh"; }

# ── videos.json diff ──────────────────────────────────────────────────────────
bold "videos.json"

if [ -f "$DST_JSON" ]; then
    if diff -q "$SRC_JSON" "$DST_JSON" >/dev/null 2>&1; then
        ok "Identical in both repos"
    else
        issue "videos.json differs — run ./sync.sh"
        $QUIET || diff <(jq -S '.' "$SRC_JSON") <(jq -S '.' "$DST_JSON") | head -30
    fi
fi

# ── Parse videos.json into categories ────────────────────────────────────────
bold "Library summary"

TOTAL=$(jq '. | length' "$SRC_JSON")
DOWNLOADED=$(jq '[.[] | select(.downloaded==true)] | length' "$SRC_JSON")
SNAPPED=$(jq '[.[] | select(.snapped==true)] | length' "$SRC_JSON")
PENDING=$(jq '[.[] | select(.downloaded==false and (.skip_reason==null or .skip_reason=="") and .available!=false)] | length' "$SRC_JSON")
SKIPPED_SIZE=$(jq '[.[] | select(.skip_reason // "" | startswith("size:"))] | length' "$SRC_JSON")
SKIPPED_DUR=$(jq '[.[] | select(.skip_reason // "" | startswith("duration:"))] | length' "$SRC_JSON")
SKIPPED_POST=$(jq '[.[] | select(.skip_reason // "" | startswith("size_post:"))] | length' "$SRC_JSON")
UNAVAILABLE=$(jq '[.[] | select(.available==false)] | length' "$SRC_JSON")
UNSNAPPED=$(jq '[.[] | select(.downloaded==true and .snapped==false)] | length' "$SRC_JSON")

info "Total       : $TOTAL"
info "Downloaded  : $DOWNLOADED"
info "Snapped     : $SNAPPED"
info "Unsnapped   : $UNSNAPPED  (mp4 should be in repo)"
info "Pending DL  : $PENDING"
info "Skipped size: $SKIPPED_SIZE (pre-download)"
info "Skipped dur : $SKIPPED_DUR"
info "Skipped post: $SKIPPED_POST (downloaded but over size limit)"
info "Unavailable : $UNAVAILABLE"

# ── Expected files in dest ────────────────────────────────────────────────────
bold "Expected mp4s in repo"

# Should be in repo: downloaded+unsnapped AND size_post (file exists but over limit)
EXPECTED_MP4_IDS=$(jq -r '.[] | select(
    .snapped==false and (
        .downloaded==true or
        (.skip_reason // "" | startswith("size_post:"))
    )
) | .id' "$SRC_JSON")

if [ -z "$EXPECTED_MP4_IDS" ]; then
    info "No mp4s expected in repo (all videos snapped or pending download)"
else
    while read -r ID; do
        [ -z "$ID" ] && continue
        TITLE=$(jq -r ".[] | select(.id==\"$ID\") | .title" "$SRC_JSON")
        SRC_MP4="$SRC/dl-$ID.mp4"
        DST_MP4="$DST/dl-$ID.mp4"

        # Check source has the file
        if [ ! -f "$SRC_MP4" ]; then
            issue "dl-$ID.mp4 missing from SOURCE — videos.json says downloaded but file gone"
            info  "  $TITLE"
            continue
        fi

        # Check dest has the file
        if [ ! -f "$DST_MP4" ]; then
            issue "dl-$ID.mp4 missing from DEST — run ./sync.sh"
            info  "  $TITLE"
            continue
        fi

        # Check they're identical
        if diff -q "$SRC_MP4" "$DST_MP4" >/dev/null 2>&1; then
            ok "dl-$ID.mp4"
            info "  $TITLE"
        else
            issue "dl-$ID.mp4 differs between source and dest — run ./sync.sh"
            info  "  $TITLE"
        fi
    done <<< "$EXPECTED_MP4_IDS"
fi

# ── Unexpected mp4s in dest ───────────────────────────────────────────────────
bold "Unexpected mp4s in repo"

FOUND_UNEXPECTED=false
for DST_MP4 in "$DST"/dl-*.mp4; do
    [ -f "$DST_MP4" ] || continue
    FNAME=$(basename "$DST_MP4")
    ID="${FNAME#dl-}"; ID="${ID%.mp4}"

    # Should it be there?
    SHOULD_BE=$(jq -r ".[] | select(
        .id==\"$ID\" and .snapped==false and (
            .downloaded==true or
            (.skip_reason // \"\" | startswith(\"size_post:\"))
        )
    ) | .id" "$SRC_JSON")

    if [ -z "$SHOULD_BE" ]; then
        SNAPPED_CHECK=$(jq -r ".[] | select(.id==\"$ID\" and .snapped==true) | .id" "$SRC_JSON")
        if [ -n "$SNAPPED_CHECK" ]; then
            warn "dl-$ID.mp4 in dest but video is now SNAPPED — should have been removed by sync"
            ISSUES=$((ISSUES + 1))
        else
            warn "dl-$ID.mp4 in dest but NOT expected (not in videos.json or already snapped)"
        fi
        FOUND_UNEXPECTED=true
    fi
done
$FOUND_UNEXPECTED || ok "No unexpected mp4s in repo"

# ── snaps/ folder check ───────────────────────────────────────────────────────
bold "snaps/ folders"

SNAPPED_IDS=$(jq -r '.[] | select(.snapped==true) | .id' "$SRC_JSON")

if [ -z "$SNAPPED_IDS" ]; then
    info "No snapped videos yet"
else
    while read -r ID; do
        [ -z "$ID" ] && continue
        TITLE=$(jq -r ".[] | select(.id==\"$ID\") | .title" "$SRC_JSON")
        SNAP_COUNT=$(jq -r ".[] | select(.id==\"$ID\") | .snap_count" "$SRC_JSON")
        SRC_DIR="$SRC/snaps/$ID"
        DST_DIR="$DST/snaps/$ID"

        # Source snaps exist?
        if [ ! -d "$SRC_DIR" ]; then
            issue "snaps/$ID/ missing from SOURCE (snapped=true but no folder)"
            continue
        fi

        SRC_COUNT=$(ls "$SRC_DIR"/*.jpg 2>/dev/null | wc -l | tr -d ' ')

        # Dest snaps exist?
        if [ ! -d "$DST_DIR" ]; then
            issue "snaps/$ID/ missing from DEST — run ./sync.sh"
            info  "  $TITLE ($SNAP_COUNT frames expected)"
            continue
        fi

        DST_COUNT=$(ls "$DST_DIR"/*.jpg 2>/dev/null | wc -l | tr -d ' ')

        # Frame count matches?
        if [ "$SRC_COUNT" -eq "$DST_COUNT" ]; then
            ok "snaps/$ID/ — $SRC_COUNT frames"
            info "  $TITLE"
        else
            issue "snaps/$ID/ frame count mismatch: source=$SRC_COUNT dest=$DST_COUNT"
            info  "  $TITLE — run ./sync.sh"
        fi

        # snap_count in videos.json matches actual files?
        if [ "$SNAP_COUNT" != "$SRC_COUNT" ]; then
            warn "snaps/$ID/ snap_count in videos.json ($SNAP_COUNT) ≠ actual files ($SRC_COUNT)"
        fi

    done <<< "$SNAPPED_IDS"
fi

# ── Orphan snaps in dest ──────────────────────────────────────────────────────
bold "Orphan snaps in repo"

FOUND_ORPHAN=false
if [ -d "$DST/snaps" ]; then
    for DST_DIR in "$DST/snaps"/*/; do
        [ -d "$DST_DIR" ] || continue
        ID=$(basename "$DST_DIR")
        IS_SNAPPED=$(jq -r ".[] | select(.id==\"$ID\" and .snapped==true) | .id" "$SRC_JSON")
        if [ -z "$IS_SNAPPED" ]; then
            warn "snaps/$ID/ in dest but video is not marked snapped — orphan, safe to remove"
            FOUND_ORPHAN=true
        fi
    done
fi
$FOUND_ORPHAN || ok "No orphan snap folders"

# ── Skipped videos report ─────────────────────────────────────────────────────
if ! $QUIET; then
    bold "Skipped / unavailable videos"
    SKIPPED=$(jq -c '.[] | select(
        (.skip_reason != null and .skip_reason != "") or .available==false
    ) | {id, title, skip_reason, available}' "$SRC_JSON")

    if [ -z "$SKIPPED" ]; then
        info "None"
    else
        while read -r item; do
            ID=$(echo "$item"     | jq -r '.id')
            TITLE=$(echo "$item"  | jq -r '.title')
            REASON=$(echo "$item" | jq -r '.skip_reason // "unavailable"')
            info "$(printf '%-22s' "$ID")  $REASON"
            info "$(printf '%-22s' '')  $TITLE"
        done <<< "$SKIPPED"
    fi
fi

# ── Final result ──────────────────────────────────────────────────────────────
sep
bold "Result"
if [ "$ISSUES" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓ All good — source and repo are in sync${NC}"
else
    echo -e "  ${RED}${BOLD}✗ $ISSUES issue(s) found — run ./sync.sh to fix${NC}"
fi
echo ""
exit $ISSUES

