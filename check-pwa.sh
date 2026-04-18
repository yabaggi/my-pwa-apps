#!/bin/bash
# ============================================================
# check-pwa.sh — PWA Configuration Checker
# Usage:
#   Check one app:  bash check-pwa.sh prom
#   Check all apps: bash check-pwa.sh --all
# Run from: your pwaApps or my-pwa-apps root folder
# ============================================================

PASS=0
FAIL=0
WARN=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color


pass() { echo -e "  ${GREEN}[✓]${NC} $1"; ((PASS++)); return 0; }
fail() { echo -e "  ${RED}[✗]${NC} $1"; ((FAIL++)); return 0; }
warn() { echo -e "  ${YELLOW}[!]${NC} $1"; ((WARN++)); return 0; }

# pass() { echo -e "  ${GREEN}[✓]${NC} $1"; #((PASS++)); }
# fail() { echo -e "  ${RED}[✗]${NC} $1"; #((FAIL++)); }
# warn() { echo -e "  ${YELLOW}[!]${NC} $1"; #((WARN++)); }
info() { echo -e "  ${CYAN}[-]${NC} $1"; }

# ============================================================
check_app() {
  local folder="$1"
  PASS=0; FAIL=0; WARN=0

  echo ""
  echo -e "${BOLD}=============================="
  echo -e "  Checking: $folder"
  echo -e "==============================${NC}"

  # ── File existence ──────────────────────────────────────
  echo -e "\n${CYAN}[ Files ]${NC}"

  [ -f "$folder/index.html" ]   && pass "index.html exists"    || fail "index.html MISSING"
  [ -f "$folder/manifest.json" ] && pass "manifest.json exists" || fail "manifest.json MISSING"
  [ -f "$folder/sw.js" ]        && pass "sw.js exists"         || fail "sw.js MISSING"
  [ -f "$folder/offline.html" ] && pass "offline.html exists"  || warn "offline.html missing (optional)"
  [ -d "$folder/icons" ]        && pass "icons/ folder exists" || warn "icons/ folder missing"

  # ── index.html checks ───────────────────────────────────
  echo -e "\n${CYAN}[ index.html ]${NC}"

  if [ -f "$folder/index.html" ]; then
    # Manifest link
    if grep -q "manifest.json" "$folder/index.html"; then
      MANIFEST_LINK=$(grep -o "href=['\"][^'\"]*manifest.json['\"]" "$folder/index.html" | head -1)
      pass "manifest linked → $MANIFEST_LINK"
      # Check if path is absolute
      echo "$MANIFEST_LINK" | grep -q "^href=['\"]/" \
        && pass "manifest link is absolute path" \
        || warn "manifest link is relative — may break in subfolders"
    else
      fail "manifest.json not linked in <head>"
    fi

    # SW registration
    if grep -q "serviceWorker.register" "$folder/index.html"; then
      SW_REG=$(grep -o "register(['\"][^'\"]*['\"])" "$folder/index.html" | head -1)
      pass "SW registration found → $SW_REG"

      # Check if relative (bad)
      echo "$SW_REG" | grep -qE "register\(['\"]sw\.js['\"]" \
        && fail "SW registered with relative path 'sw.js' — should be absolute" \
        || pass "SW path is not bare 'sw.js'"

      # Check if contains folder name (good)
      echo "$SW_REG" | grep -q "$folder" \
        && pass "SW path contains folder name /$folder/" \
        || warn "SW path may not match correct scope"

    else
      fail "serviceWorker.register() not found"
    fi

    # Viewport meta
    grep -q "viewport" "$folder/index.html" \
      && pass "viewport meta tag present" \
      || warn "viewport meta tag missing"

    # Theme color meta
    grep -q "theme-color" "$folder/index.html" \
      && pass "theme-color meta present" \
      || warn "theme-color meta missing"

    # Apple PWA meta
    grep -q "apple-mobile-web-app" "$folder/index.html" \
      && pass "Apple PWA meta present" \
      || warn "Apple PWA meta missing (optional)"
  fi

  # ── manifest.json checks ────────────────────────────────
  echo -e "\n${CYAN}[ manifest.json ]${NC}"

  if [ -f "$folder/manifest.json" ]; then
    # start_url
    if grep -q "start_url" "$folder/manifest.json"; then
      START_URL=$(grep -o '"start_url"[^,]*' "$folder/manifest.json" | head -1)
      pass "start_url found → $START_URL"
      echo "$START_URL" | grep -q "/$folder/" \
        && pass "start_url contains /$folder/" \
        || fail "start_url missing /$folder/ — wrong path"
    else
      fail "start_url missing"
    fi

    # scope
    if grep -q '"scope"' "$folder/manifest.json"; then
      SCOPE=$(grep -o '"scope"[^,]*' "$folder/manifest.json" | head -1)
      pass "scope found → $SCOPE"
      echo "$SCOPE" | grep -q "/$folder/" \
        && pass "scope contains /$folder/" \
        || fail "scope missing /$folder/ — wrong path"
    else
      fail "scope missing"
    fi

    # name
    grep -q '"name"' "$folder/manifest.json" \
      && pass "name present" \
      || fail "name missing"

    # short_name
    grep -q '"short_name"' "$folder/manifest.json" \
      && pass "short_name present" \
      || warn "short_name missing"

    # display
    grep -q '"display"' "$folder/manifest.json" \
      && pass "display present" \
      || warn "display missing"

    # icons
    if grep -q '"icons"' "$folder/manifest.json"; then
      ICON_COUNT=$(grep -c '"src"' "$folder/manifest.json")
      pass "icons array present ($ICON_COUNT icons)"
      # Check icon paths are absolute
      FIRST_ICON=$(grep -o '"src": "[^"]*"' "$folder/manifest.json" | head -1)
      echo "$FIRST_ICON" | grep -q '"src": "/" ' \
        && pass "icon paths are absolute" \
        || info "icon path sample → $FIRST_ICON"
    else
      fail "icons array missing"
    fi

    # theme_color
    grep -q '"theme_color"' "$folder/manifest.json" \
      && pass "theme_color present" \
      || warn "theme_color missing"

    # background_color
    grep -q '"background_color"' "$folder/manifest.json" \
      && pass "background_color present" \
      || warn "background_color missing"
  fi

  # ── sw.js checks ────────────────────────────────────────
  echo -e "\n${CYAN}[ sw.js ]${NC}"

  if [ -f "$folder/sw.js" ]; then
    # CACHE_NAME
    if grep -q "CACHE_NAME" "$folder/sw.js"; then
      CACHE=$(grep -o "CACHE_NAME = '[^']*'" "$folder/sw.js" | head -1)
      pass "CACHE_NAME found → $CACHE"
    else
      fail "CACHE_NAME missing"
    fi

    # urlsToCache
    if grep -q "urlsToCache" "$folder/sw.js"; then
      URL_COUNT=$(grep -c "/$folder/" "$folder/sw.js")
      pass "urlsToCache found ($URL_COUNT paths with /$folder/)"
      # Check for bare paths without folder
      grep "urlsToCache" "$folder/sw.js" | grep -q '"/"' \
        && fail "urlsToCache contains bare '/' — should be '/$folder/'" \
        || pass "No bare '/' paths in urlsToCache"
    else
      fail "urlsToCache missing"
    fi

    # install event
    grep -q "addEventListener('install'" "$folder/sw.js" \
      && pass "install event handler present" \
      || fail "install event handler missing"

    # activate event
    grep -q "addEventListener('activate'" "$folder/sw.js" \
      && pass "activate event handler present" \
      || fail "activate event handler missing"

    # fetch event
    grep -q "addEventListener('fetch'" "$folder/sw.js" \
      && pass "fetch event handler present" \
      || fail "fetch event handler MISSING — offline will not work"

    # skipWaiting
    grep -q "skipWaiting" "$folder/sw.js" \
      && pass "skipWaiting() present" \
      || warn "skipWaiting() missing — needs 2 reloads to activate"

    # clients.claim
    grep -q "clients.claim" "$folder/sw.js" \
      && pass "clients.claim() present" \
      || warn "clients.claim() missing — SW won't control current tab immediately"

    # respondWith
    grep -q "respondWith" "$folder/sw.js" \
      && pass "respondWith() present in fetch handler" \
      || fail "respondWith() missing — SW won't intercept requests"

    # OFFLINE_URL
    if grep -q "OFFLINE_URL" "$folder/sw.js"; then
      OFFLINE=$(grep -o "OFFLINE_URL = '[^']*'" "$folder/sw.js" | head -1)
      pass "OFFLINE_URL found → $OFFLINE"
      echo "$OFFLINE" | grep -q "/$folder/" \
        && pass "OFFLINE_URL contains /$folder/" \
        || fail "OFFLINE_URL missing /$folder/ — wrong path"
    else
      warn "OFFLINE_URL not defined (optional)"
    fi

    # Duplicate cache entries
    DUPES=$(grep -o '"[^"]*"' "$folder/sw.js" | sort | uniq -d | grep "/$folder/")
    [ -n "$DUPES" ] \
      && warn "Duplicate cache entries found: $DUPES" \
      || pass "No duplicate cache entries"
  fi

  # ── Summary ─────────────────────────────────────────────
  echo ""
  echo -e "${BOLD}------------------------------"
  TOTAL=$((PASS + FAIL + WARN))
  echo -e "  ${GREEN}Pass: $PASS${NC}  ${RED}Fail: $FAIL${NC}  ${YELLOW}Warn: $WARN${NC}  (Total: $TOTAL checks)"
  if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}✓ $folder looks good!${NC}"
  else
    echo -e "  ${RED}✗ $folder has $FAIL critical issue(s) to fix${NC}"
  fi
  echo -e "${BOLD}------------------------------${NC}"
}

# ============================================================
# Entry point
# ============================================================

if [ "$1" = "--all" ]; then
  TOTAL_PASS=0; TOTAL_FAIL=0; TOTAL_WARN=0
  APP_COUNT=0

  for dir in */; do
    folder="${dir%/}"
    [ ! -f "$folder/index.html" ] && continue
    check_app "$folder"
    ((TOTAL_PASS+=PASS))
    ((TOTAL_FAIL+=FAIL))
    ((TOTAL_WARN+=WARN))
    ((APP_COUNT++))
  done

  echo ""
  echo -e "${BOLD}=============================="
  echo -e "  SUMMARY — All $APP_COUNT Apps"
  echo -e "=============================="
  echo -e "  ${GREEN}Total Pass: $TOTAL_PASS${NC}"
  echo -e "  ${RED}Total Fail: $TOTAL_FAIL${NC}"
  echo -e "  ${YELLOW}Total Warn: $TOTAL_WARN${NC}"
  echo -e "${BOLD}==============================${NC}"

elif [ -n "$1" ]; then
  if [ ! -d "$1" ]; then
    echo "Error: folder '$1' not found"
    exit 1
  fi
  check_app "$1"

else
  echo "Usage:"
  echo "  bash check-pwa.sh prom          # check one app"
  echo "  bash check-pwa.sh --all         # check all apps"
fi


